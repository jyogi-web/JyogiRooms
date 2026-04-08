# frozen_string_literal: true

# Discord REST APIに直接通知を送信するサービス
# 通知失敗はログに記録するのみで、メインの処理をブロックしない
class DiscordNotifier
  DISCORD_API_BASE = "https://discord.com/api/v10"
  TIMEOUT_SECONDS = 5

  RESERVATION_LABELS = {
    "reservation_created" => { title: "📅 予約が作成されました", color: 0x00cc66 },
    "reservation_updated" => { title: "📝 予約が更新されました", color: 0xff9900 },
    "reservation_destroyed" => { title: "🗑️ 予約が削除されました", color: 0xff3333 }
  }.freeze

  KEY_LABELS = {
    "key_transferred" => { title: "🔑 鍵が譲渡されました", color: 0x0099ff },
    "key_assigned" => { title: "🔑 鍵が割り当てられました", color: 0x00cc66 },
    "key_unassigned" => { title: "🔑 鍵の割り当てが解除されました", color: 0xff9900 }
  }.freeze

  ROOM_LABELS = {
    "room_entered" => { title: "📱 入室しました", color: 0x00cc66 },
    "room_exited" => { title: "📱 退室しました", color: 0xff9900 },
    "room_opened" => { title: "🔓 部室が開きました", color: 0x0099ff },
    "room_closed" => { title: "🔒 部室が閉まりました", color: 0xff3333 }
  }.freeze

  def self.notify(type:, data:)
    return unless enabled?

    if type.start_with?("reservation_")
      send_reservation_notification(type, data)
    elsif type.start_with?("key_")
      send_key_notification(type, data)
    elsif type.start_with?("room_")
      send_room_notification(type, data)
    else
      Rails.logger.error("Discord notification: unknown type #{type}")
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

  # 施錠アナウンスを送信する
  def self.send_lock_announce(message = nil)
    message ||= "🔒 **施錠のお知らせ**\n\n部室の施錠時間です!\n鍵持ちの部員は各部室が施錠されているか確認をお願いします。"
    post_message({ content: message })
    Rails.logger.info("施錠アナウンスを送信しました")
  rescue => e
    Rails.logger.error("施錠アナウンス送信失敗: #{e.message}")
  end

  def self.enabled?
    bot_token.present? && channel_id.present?
  end

  def self.bot_token
    ENV["DISCORD_BOT_TOKEN"]
  end

  def self.channel_id
    ENV["ANNOUNCE_CHANNEL_ID"]
  end

  def self.entry_channel_id
    ENV.fetch("ENTRY_CHANNEL_ID", channel_id)
  end

  # Discord APIにメッセージを送信する
  def self.post_message(body, target_channel_id: channel_id)
    uri = URI("#{DISCORD_API_BASE}/channels/#{target_channel_id}/messages")
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bot #{bot_token}"
    request.body = body.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS
    response = http.request(request)
    unless response.code.to_i.between?(200, 299)
      Rails.logger.error("Discord API error: #{response.code} #{response.body}")
    end
  end

  def self.format_user_mention(discord_id, display_name)
    discord_id.present? ? "<@#{discord_id}>" : (display_name || "不明なユーザー")
  end

  WDAYS = %w[日 月 火 水 木 金 土].freeze

  def self.format_date_time(start_at, end_at)
    start_time = Time.parse(start_at).in_time_zone("Asia/Tokyo")
    end_time = Time.parse(end_at).in_time_zone("Asia/Tokyo")
    wday = WDAYS[start_time.wday]
    date_str = start_time.strftime("%-m/%-d(#{wday})")
    "#{date_str} #{start_time.strftime("%H:%M")} ~ #{end_time.strftime("%H:%M")}"
  end

  def self.send_reservation_notification(type, data)
    label = RESERVATION_LABELS[type] || { title: "📅 予約通知", color: 0x0099ff }
    user = format_user_mention(data[:user_discord_id], data[:user_display_name])
    date_time = format_date_time(data[:start_at], data[:end_at])
    purpose = data[:purpose].presence || "なし"

    description = "#{user} の予約\n📅 #{date_time}\n📝 #{purpose}"

    post_message({
      embeds: [ {
        title: label[:title],
        description: description,
        color: label[:color],
        timestamp: Time.current.iso8601
      } ]
    })

    # 予約作成時のみ鍵持ちにメンション
    if type == "reservation_created"
      holders = (data[:key_holders] || []).select { |h| h[:discord_id].present? }
      if holders.any?
        mentions = holders.map { |h| "<@#{h[:discord_id]}>" }.join(" ")
        post_message({
          content: "🔑 #{mentions}\n上記の日時に部室を開けられる方はリアクションをお願いします！"
        })
      end
    end
  end

  def self.send_key_notification(type, data)
    label = KEY_LABELS[type] || { title: "🔑 鍵通知", color: 0x0099ff }
    room_name = "#{data[:room_name]}（#{data[:room_number]}）"

    description = "🚪 #{room_name}\n"
    case type
    when "key_transferred"
      from = format_user_mention(data[:from_user_discord_id], data[:from_user_display_name])
      to = format_user_mention(data[:to_user_discord_id], data[:to_user_display_name])
      description += "#{from} → #{to}"
    when "key_assigned"
      to = format_user_mention(data[:to_user_discord_id], data[:to_user_display_name])
      description += "#{to} に割り当て"
    when "key_unassigned"
      from = format_user_mention(data[:from_user_discord_id], data[:from_user_display_name])
      description += "#{from} の割り当てを解除"
    end

    post_message({
      embeds: [ {
        title: label[:title],
        description: description,
        color: label[:color],
        timestamp: Time.current.iso8601
      } ]
    })
  end

  def self.send_room_notification(type, data)
    label = ROOM_LABELS[type] || { title: "🚪 部室通知", color: 0x0099ff }
    room_name = "#{data[:room_name]}（#{data[:room_number]}）"
    user = format_user_mention(data[:user_discord_id], data[:user_display_name])

    # 入退室は専用チャンネル、開閉は通常チャンネル
    target = %w[room_entered room_exited].include?(type) ? entry_channel_id : channel_id

    post_message({
      embeds: [ {
        title: label[:title],
        description: "🚪 #{room_name}\n#{user}",
        color: label[:color],
        timestamp: Time.current.iso8601
      } ]
    }, target_channel_id: target)
  end

  private_class_method :post_message, :format_user_mention, :format_date_time,
                       :send_reservation_notification, :send_key_notification,
                       :send_room_notification, :bot_token, :channel_id,
                       :entry_channel_id
end
