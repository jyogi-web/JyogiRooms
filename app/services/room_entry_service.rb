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
    auto_closed_previous_room = false
    auto_opened = false

    visit = ActiveRecord::Base.transaction do
      # 行ロックで同時リクエストをシリアライズ
      user.lock!
      room.lock!

      now = Time.current

      # 別の部室に入室中なら先に退室
      current_visit = RoomVisit.active.for_user(user).first
      if current_visit
        raise EntryError, "既にこの部室に入室中です" if current_visit.room_id == room.id

        current_visit.update!(exited_at: now)
        auto_exited_room = current_visit.room

        # その部室が空になったら閉室
        if RoomVisit.active.for_room(auto_exited_room).none?
          active_session = RoomSession.active.for_room(auto_exited_room).lock.first
          if active_session
            active_session.update!(closed_at: now, closed_by: user)
            auto_closed_previous_room = true
            auto_exited_room.room_status.update!(is_open: false, opened_at: nil, opened_by: nil, occupants: [], occupant_count: 0)
          else
            remove_occupant_from_status(auto_exited_room, user)
          end
        else
          remove_occupant_from_status(auto_exited_room, user)
        end
      end

      # 部室が閉まっていれば自動開室
      unless RoomSession.active.for_room(room).exists?
        RoomSession.create!(room: room, opened_by: user, opened_at: now)
        auto_opened = true
      end

      visit = RoomVisit.create!(room: room, user: user, entered_at: now, source: source)
      add_occupant_to_status(room, user, now)

      # 自動開室した場合は is_open も更新（入室者追加と同時に反映）
      if auto_opened
        room.room_status.update!(is_open: true, opened_at: now, opened_by: user)
      end

      visit
    end

    # トランザクション成功後に通知
    if auto_exited_room
      DiscordNotifier.notify(type: "room_exited", data: room_entry_data(auto_exited_room, user))
      DiscordNotifier.notify(type: "room_closed", data: room_entry_data(auto_exited_room, user)) if auto_closed_previous_room
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
      # 行ロックで同一ユーザー・同一部室の同時リクエストをシリアライズ
      user.lock!
      room.lock!

      now = Time.current

      current_visit = RoomVisit.active.for_room(room).for_user(user).first
      raise EntryError, "この部室に入室していません" unless current_visit

      current_visit.update!(exited_at: now)

      # 入室者が0人になったら閉室
      if RoomVisit.active.for_room(room).none?
        active_session = RoomSession.active.for_room(room).lock.first
        if active_session
          active_session.update!(closed_at: now, closed_by: user)
          auto_closed = true
          room.room_status.update!(is_open: false, opened_at: nil, opened_by: nil, occupants: [], occupant_count: 0)
        else
          remove_occupant_from_status(room, user)
        end
      else
        remove_occupant_from_status(room, user)
      end

      current_visit
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

  def self.add_occupant_to_status(room, user, entered_at)
    status = room.room_status
    new_occupant = { "user_id" => user.id, "display_name" => user.display_name, "entered_at" => entered_at.iso8601 }
    status.update!(
      occupants: status.occupants + [ new_occupant ],
      occupant_count: status.occupant_count + 1
    )
  end

  def self.remove_occupant_from_status(room, user)
    status = room.room_status
    status.update!(
      occupants: status.occupants.reject { |o| o["user_id"] == user.id },
      occupant_count: [ status.occupant_count - 1, 0 ].max
    )
  end

  private_class_method :room_entry_data, :add_occupant_to_status, :remove_occupant_from_status
end
