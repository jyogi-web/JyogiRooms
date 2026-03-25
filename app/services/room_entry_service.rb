# frozen_string_literal: true

# 入退室に関する業務ロジック
# - 入室時: 別部室に入室中なら先に退室、部室が閉まっていれば自動開室
# - 退室時: 入室者が0人になったら自動閉室
class RoomEntryService
  class EntryError < StandardError; end

  # 入室する
  #
  # @param room [Room]
  # @param user [User]
  # @param source [String] "nfc", "web", "discord"
  # @return [RoomVisit]
  def self.enter(room:, user:, source: "web")
    auto_exited_room = nil
    auto_opened = false

    visit = ActiveRecord::Base.transaction do
      # 別の部室に入室中なら先に退室
      current_visit = RoomVisit.active.for_user(user).lock.first
      if current_visit
        raise EntryError, "既にこの部室に入室中です" if current_visit.room_id == room.id

        current_visit.update!(exited_at: Time.current)
        auto_exited_room = current_visit.room

        # その部室が空になったら閉室
        if RoomVisit.active.for_room(auto_exited_room).none?
          active_session = RoomSession.active.for_room(auto_exited_room).lock.first
          active_session&.update!(closed_at: Time.current, closed_by: user)
        end
      end

      # 部室が閉まっていれば自動開室
      unless RoomSession.active.for_room(room).exists?
        RoomSession.create!(room: room, opened_by: user, opened_at: Time.current)
        auto_opened = true
      end

      RoomVisit.create!(room: room, user: user, entered_at: Time.current, source: source)
    end

    # トランザクション成功後に通知
    if auto_exited_room
      DiscordNotifier.notify(type: "room_exited", data: room_entry_data(auto_exited_room, user))
    end
    DiscordNotifier.notify(type: "room_opened", data: room_entry_data(room, user)) if auto_opened
    DiscordNotifier.notify(type: "room_entered", data: room_entry_data(room, user))

    visit
  end

  # 退室する
  #
  # @param room [Room]
  # @param user [User]
  # @return [RoomVisit]
  def self.exit(room:, user:)
    auto_closed = false

    visit = ActiveRecord::Base.transaction do
      visit = RoomVisit.active.for_room(room).for_user(user).lock.first
      raise EntryError, "この部室に入室していません" unless visit

      visit.update!(exited_at: Time.current)

      # 入室者が0人になったら閉室
      if RoomVisit.active.for_room(room).none?
        active_session = RoomSession.active.for_room(room).lock.first
        if active_session
          active_session.update!(closed_at: Time.current, closed_by: user)
          auto_closed = true
        end
      end

      visit
    end

    # トランザクション成功後に通知
    DiscordNotifier.notify(type: "room_exited", data: room_entry_data(room, user))
    DiscordNotifier.notify(type: "room_closed", data: room_entry_data(room, user)) if auto_closed

    visit
  end

  # NFC用トグル: 入室中なら退室、そうでなければ入室
  #
  # @param room [Room]
  # @param user [User]
  # @param source [String]
  # @return [Hash] { action: "enter"|"exit", visit: RoomVisit }
  def self.toggle(room:, user:, source: "nfc")
    current_visit = RoomVisit.active.for_room(room).for_user(user).first
    if current_visit
      visit = self.exit(room: room, user: user)
      { action: "exit", visit: visit }
    else
      visit = enter(room: room, user: user, source: source)
      { action: "enter", visit: visit }
    end
  end

  def self.room_entry_data(room, user)
    {
      room_name: room.name,
      room_number: room.room_number,
      user_display_name: user.display_name,
      user_discord_id: user.discord_id
    }
  end

  private_class_method :room_entry_data
end
