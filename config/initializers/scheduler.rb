# frozen_string_literal: true

return unless defined?(Rails::Server) || ENV["SOLID_QUEUE_IN_PUMA"]

# 複数ワーカー(WEB_CONCURRENCY > 1)時に重複起動を防ぐ
return if ENV.fetch("WEB_CONCURRENCY", "1").to_i > 1 && !ENV["SCHEDULER_ENABLED"]

require "rufus-scheduler"

scheduler = Rufus::Scheduler.singleton

# 毎日20:00 JST に施錠アナウンスを送信
scheduler.cron("0 20 * * * Asia/Tokyo") do
  Rails.logger.info("[Scheduler] 施錠アナウンス実行")
  LockAnnounceJob.perform_now
rescue => e
  Rails.logger.error("[Scheduler] 施錠アナウンス失敗: #{e.message}")
end

# テスト用: テストアナウンスを送信
scheduler.cron("30 13 * * * Asia/Tokyo") do
  Rails.logger.info("[Scheduler] 13:30の定刻テスト実行")
  DiscordNotifier.send(:post_message, {
    content: "🧪 **定刻テスト実行(13:30)**\n\n自宅で稼働中のラズパイから新鮮なJyogiRoomsをお届け中！"
  })
rescue => e
  Rails.logger.error("[Scheduler] テスト失敗: #{e.message}")
end
