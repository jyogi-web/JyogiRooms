# frozen_string_literal: true

# 閲覧ログ記録の入口（Web 経路）。
# - 実際の保存は RoomViewLogJob 経由で view-log-worker(Cloudflare) が担う。
# - ここでの throttle は「無駄なジョブ投入を抑える一次判定」であり、
#   経路横断（Web/Discord）の最終的な5分重複判定は Worker 側 KV が権威。
#   ※本アプリの本番キャッシュがプロセスローカルでも、Worker 側で必ず間引かれる。
class RoomViewLogger
  THROTTLE_WINDOW = 5.minutes
  # app: アプリ全体へのアクセス（画面種別を問わない。5分窓でセッション的に数える）
  VALID_CATEGORIES = %w[room_status ranking stats app].freeze

  # ログイン中ユーザーの Web 閲覧を記録する。
  # メイン処理をブロック・失敗させないよう、例外は握りつぶしてログのみ。
  # @param user [User, nil]
  # @param category [String] "room_status" / "ranking" / "stats" / "app"
  def self.log_web_view(user, category: "room_status")
    return if user.blank?
    return unless enabled?

    category = "room_status" unless VALID_CATEGORIES.include?(category)
    return unless should_enqueue?(user, category)

    RoomViewLogJob.perform_later(
      "web",
      category: category,
      user_id: user.id,
      discord_id: nil,
      viewed_at: Time.current.utc.iso8601
    )
  rescue => e
    Rails.logger.error("[RoomViewLogger] failed to enqueue web view log: #{e.class}: #{e.message}")
  end

  # 一次throttle: 5分窓で既に投入済みならジョブを作らない（カテゴリ別）。
  # キャッシュ障害（write が例外）時は fail-open（ジョブ投入を止めない）。
  # 経路横断の最終的な重複判定は Worker 側 KV が権威なので、ここが緩くても実害はない。
  def self.should_enqueue?(user, category)
    cache_key = "view_log_throttle:web:#{category}:#{user.id}"
    # unless_exist: true → 新規書き込み成功で true、キー存在（＝throttle対象）で false
    Rails.cache.write(cache_key, true, expires_in: THROTTLE_WINDOW, unless_exist: true)
  rescue => e
    Rails.logger.warn("[RoomViewLogger] throttle cache error, fail-open: #{e.class}: #{e.message}")
    true
  end

  def self.enabled?
    ENV["VIEW_LOG_INGEST_URL"].present? && ENV["VIEW_LOG_INGEST_SECRET"].present?
  end
end
