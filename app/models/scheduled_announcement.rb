# frozen_string_literal: true

class ScheduledAnnouncement < ApplicationRecord
  DEFAULT_MESSAGE = "🔒 **施錠のお知らせ**\n\n部室の施錠時間です!\n鍵持ちの部員は各部室が施錠されているか確認をお願いします。"

  validates :message, presence: true
  validates :hour, presence: true, inclusion: { in: 0..23 }
  validates :minute, presence: true, inclusion: { in: 0..59 }

  after_commit(on: %i[create update destroy]) { Rails.cache.delete("scheduled_announcement") }

  # シングルトンレコード（1件のみ使用）
  def self.current
    first_or_create!(
      message: DEFAULT_MESSAGE,
      hour: 20,
      minute: 0
    )
  end

  def scheduled_time_display
    format("%<hour>02d:%<minute>02d", hour: hour, minute: minute)
  end
end
