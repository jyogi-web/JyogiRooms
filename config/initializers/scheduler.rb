# frozen_string_literal: true

return unless defined?(Rails::Server) || ENV["SOLID_QUEUE_IN_PUMA"]

require "rufus-scheduler"

scheduler = Rufus::Scheduler.singleton

# 毎日20:00 JST に施錠アナウンスを送信
scheduler.cron("0 20 * * * Asia/Tokyo") do
  Rails.logger.info("[Scheduler] 施錠アナウンス実行")
  LockAnnounceJob.perform_now
rescue => e
  Rails.logger.error("[Scheduler] 施錠アナウンス失敗: #{e.message}")
end
