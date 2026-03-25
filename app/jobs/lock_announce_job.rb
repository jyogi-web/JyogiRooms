# frozen_string_literal: true

class LockAnnounceJob < ApplicationJob
  def perform
    return unless DiscordNotifier.enabled?

    announcement = ScheduledAnnouncement.find_by(enabled: true)
    return unless announcement

    DiscordNotifier.send_lock_announce(announcement.message)
  end
end
