# frozen_string_literal: true

return unless defined?(Rails::Server) || ENV["SOLID_QUEUE_IN_PUMA"]

# 複数ワーカー(WEB_CONCURRENCY > 1)時に重複起動を防ぐ
return if ENV.fetch("WEB_CONCURRENCY", "1").to_i > 1 && !ENV["SCHEDULER_ENABLED"]

require "rufus-scheduler"

scheduler = Rufus::Scheduler.singleton

# 毎分チェックして、設定された時刻と一致したら施錠アナウンスを実行
scheduler.cron("* * * * * Asia/Tokyo") do
  now = Time.current.in_time_zone("Asia/Tokyo")
  announcement = Rails.cache.fetch("scheduled_announcement") do
    ScheduledAnnouncement.find_by(enabled: true)
  end
  next unless announcement
  next unless now.hour == announcement.hour && now.min == announcement.minute

  Rails.logger.info("[Scheduler] 施錠アナウンス実行 (#{announcement.scheduled_time_display})")
  LockAnnounceJob.perform_now
rescue => e
  Rails.logger.error("[Scheduler] 施錠アナウンス失敗: #{e.message}")
end
