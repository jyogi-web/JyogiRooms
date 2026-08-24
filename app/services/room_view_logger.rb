# frozen_string_literal: true

# 部室状況の閲覧ログ記録の入口（Web 経路）。
# - 実際の保存は RoomViewLogJob 経由で view-log-worker(Cloudflare) が担う。
# - ここでの throttle は「無駄なジョブ投入を抑える一次判定」であり、
#   経路横断（Web/Discord）の最終的な5分重複判定は Worker 側 KV が権威。
#   ※本アプリの本番キャッシュがプロセスローカルでも、Worker 側で必ず間引かれる。
class RoomViewLogger
  THROTTLE_WINDOW = 5.minutes

  # ログイン中ユーザーの Web 閲覧を記録する（ダッシュボード表示時に呼ぶ）。
  # メイン処理をブロック・失敗させないよう、例外は握りつぶしてログのみ。
  # @param user [User, nil]
  def self.log_web_view(user)
    return if user.blank?
    return unless enabled?

    # 一次throttle: 5分窓で既に投入済みならジョブを作らない
    cache_key = "view_log_throttle:web:#{user.id}"
    return unless Rails.cache.write(cache_key, true, expires_in: THROTTLE_WINDOW, unless_exist: true)

    RoomViewLogJob.perform_later(
      "web",
      user_id: user.id,
      discord_id: nil,
      viewed_at: Time.current.utc.iso8601
    )
  rescue => e
    Rails.logger.error("[RoomViewLogger] failed to enqueue web view log: #{e.class}: #{e.message}")
  end

  def self.enabled?
    ENV["VIEW_LOG_INGEST_URL"].present? && ENV["VIEW_LOG_INGEST_SECRET"].present?
  end
end
