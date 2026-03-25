# frozen_string_literal: true

class LockAnnounceJob < ApplicationJob
  def perform
    return unless DiscordNotifier.enabled?

    DiscordNotifier.send_lock_announce
  end
end
