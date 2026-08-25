# frozen_string_literal: true

require "net/http"
require "uri"

# view-log-worker の集計エンドポイント（GET /view-logs/stats）を叩くクライアント。
# CF API トークンは Rails に置かず、取り込みと同じ共有シークレットで認可する。
class ViewLogStatsClient
  TIMEOUT_SECONDS = 8

  Result = Struct.new(:ok, :data, :error, keyword_init: true)

  # @param days [Integer] 日別集計の対象日数
  # @param limit [Integer] 最近の閲覧の取得件数
  # @param category [String, nil] カテゴリ絞り込み（nil は全体）
  # @return [Result]
  def self.fetch(days: 30, limit: 50, category: nil)
    ingest_url = ENV["VIEW_LOG_INGEST_URL"]
    secret = ENV["VIEW_LOG_INGEST_SECRET"]
    return Result.new(ok: false, error: "閲覧ログ連携が未設定です（VIEW_LOG_INGEST_URL / VIEW_LOG_INGEST_SECRET）") if ingest_url.blank? || secret.blank?

    uri = URI("#{ingest_url}/stats")
    query = { days: days, limit: limit }
    query[:category] = category if category.present?
    uri.query = URI.encode_www_form(query)

    request = Net::HTTP::Get.new(uri.request_uri)
    request["X-Ingest-Secret"] = secret

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS

    response = http.request(request)
    unless response.code.to_i == 200
      return Result.new(ok: false, error: "集計取得に失敗しました (HTTP #{response.code})")
    end

    Result.new(ok: true, data: JSON.parse(response.body))
  rescue => e
    Rails.logger.error("[ViewLogStatsClient] #{e.class}: #{e.message}")
    Result.new(ok: false, error: "集計取得中にエラーが発生しました")
  end
end
