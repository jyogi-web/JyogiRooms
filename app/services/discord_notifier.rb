# frozen_string_literal: true

# Discord Botに通知を送信するサービス
# 通知失敗はログに記録するのみで、メインの処理をブロックしない
class DiscordNotifier
  TIMEOUT_SECONDS = 5

  def self.notify(type:, data:)
    return unless enabled?

    uri = URI("#{bot_base_url.chomp('/')}/notify")
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["X-Api-Key"] = notify_api_key
    request.body = { type: type, data: data }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS
    response = http.request(request)
    unless response.code.to_i.between?(200, 299)
      Rails.logger.error("Discord notification HTTP error (#{type}): #{response.code} #{response.body}")
    end
  rescue => e
    Rails.logger.error("Discord notification failed (#{type}): #{e.message}")
  end

  # 予約通知用データを構築する
  def self.reservation_data(reservation)
    notify_room_id = ENV.fetch("NOTIFY_ROOM_ID", "3").to_i
    key_holders = Key.where(room_id: notify_room_id)
                     .where.not(user_id: nil)
                     .includes(:user)
                     .map { |k| { discord_id: k.user.discord_id, display_name: k.user.display_name } }

    {
      user_display_name: reservation.user.display_name,
      user_discord_id: reservation.user.discord_id,
      start_at: reservation.start_at&.iso8601,
      end_at: reservation.end_at&.iso8601,
      purpose: reservation.purpose,
      key_holders: key_holders
    }
  end

  # 鍵通知用データを構築する
  def self.key_data(room, from_user: nil, to_user: nil)
    {
      room_name: room.name,
      room_number: room.room_number,
      from_user_display_name: from_user&.display_name,
      from_user_discord_id: from_user&.discord_id,
      to_user_display_name: to_user&.display_name,
      to_user_discord_id: to_user&.discord_id
    }
  end

  def self.enabled?
    bot_base_url.present? && notify_api_key.present?
  end

  def self.bot_base_url
    ENV["DISCORD_BOT_URL"]
  end

  def self.notify_api_key
    ENV["DISCORD_NOTIFY_API_KEY"]
  end
end
