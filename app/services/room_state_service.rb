# frozen_string_literal: true

# 部室の開閉に関する業務ロジック
# - 閉室時は入室中の全ユーザーを退室処理
class RoomStateService
  class StateError < StandardError; end

  # 開室する
  #
  # @param room [Room]
  # @param user [User]
  # @return [RoomSession]
  def self.open(room:, user:)
    now = Time.current

    session = ActiveRecord::Base.transaction do
      # 部室行ロックで同一部室の同時リクエストをシリアライズ
      room.lock!

      raise StateError, "この部室は既に開室しています" if RoomSession.active.for_room(room).exists?

      session = RoomSession.create!(room: room, opened_by: user, opened_at: now)
      room.room_status.update!(is_open: true, opened_at: now, opened_by: user)

      session
    end

    DiscordNotifier.notify(type: "room_opened", data: room_state_data(room, user))

    session
  end

  # 閉室する（入室中の全ユーザーも退室させる）
  #
  # @param room [Room]
  # @param user [User]
  # @return [RoomSession]
  def self.close(room:, user:)
    session = ActiveRecord::Base.transaction do
      # 部室行ロックで同一部室の同時リクエストをシリアライズ
      room.lock!

      session = RoomSession.active.for_room(room).first
      raise StateError, "この部室は開室していません" unless session

      RoomVisit.active.for_room(room).update_all(exited_at: Time.current)
      session.update!(closed_at: Time.current, closed_by: user)
      room.room_status.update!(is_open: false, opened_at: nil, opened_by: nil, occupants: [], occupant_count: 0)

      session
    end

    DiscordNotifier.notify(type: "room_closed", data: room_state_data(room, user))

    session
  end

  # 部室が開室中か
  def self.open?(room:)
    RoomSession.active.for_room(room).exists?
  end

  # 現在のセッションを取得
  def self.current_session(room:)
    RoomSession.active.for_room(room).first
  end

  # 現在入室中のユーザー一覧
  def self.current_occupants(room:)
    User.joins(:room_visits).where(room_visits: { room_id: room.id, exited_at: nil })
  end

  def self.room_state_data(room, user)
    {
      room_name: room.name,
      room_number: room.room_number,
      user_display_name: user.display_name,
      user_discord_id: user.discord_id
    }
  end

  private_class_method :room_state_data
end
