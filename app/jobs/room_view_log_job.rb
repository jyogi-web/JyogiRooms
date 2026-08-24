# frozen_string_literal: true

require "net/http"
require "uri"

# 閲覧ログを view-log-worker（Cloudflare）へ非同期に送信するジョブ。
# 保存先は Cloudflare D1 なので Neon の容量・書き込みは消費しない。
#
# 注意（配送の耐久性）:
#   本アプリの ActiveJob アダプタは既定（:async / インプロセス）のため、
#   プロセス再起動をまたぐと未処理ジョブは失われる（ベストエフォート配送）。
#   「一件も漏らさず」を完全に担保したい場合は、queue_adapter を :solid_queue に
#   切り替える（＝ジョブ行が Neon に載る点はトレードオフ）。
class RoomViewLogJob < ApplicationJob
  class IngestError < StandardError; end

  queue_as :default

  # 5xx / タイムアウト / 一時的な接続エラーはリトライ。4xx（検証エラー等）はリトライしない。
  retry_on IngestError,
           Net::OpenTimeout, Net::ReadTimeout,
           SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError,
           wait: :polynomially_longer, attempts: 5

  TIMEOUT_SECONDS = 5

  # @param source [String] "web" / "discord"
  # @param user_id [Integer, nil] Rails users.id
  # @param discord_id [String, nil] Discord ユーザーID
  # @param viewed_at [String] UTC ISO8601
  def perform(source, user_id:, discord_id:, viewed_at:)
    url = ENV["VIEW_LOG_INGEST_URL"]
    secret = ENV["VIEW_LOG_INGEST_SECRET"]
    return if url.blank? || secret.blank?

    uri = URI(url)
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["X-Ingest-Secret"] = secret
    request.body = {
      source: source,
      user_id: user_id,
      discord_id: discord_id,
      viewed_at: viewed_at
    }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS

    response = http.request(request)
    code = response.code.to_i

    # 201=記録 / 200=throttled(間引き) はどちらも成功扱い
    return if code == 200 || code == 201

    # 5xx はリトライ、4xx は恒久エラーとしてログのみ
    if code >= 500
      raise IngestError, "view-log ingest returned #{code}: #{response.body}"
    else
      Rails.logger.error("[RoomViewLogJob] non-retryable #{code}: #{response.body}")
    end
  end
end
