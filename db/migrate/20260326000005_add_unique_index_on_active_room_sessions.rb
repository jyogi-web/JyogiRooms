# frozen_string_literal: true

class AddUniqueIndexOnActiveRoomSessions < ActiveRecord::Migration[8.1]
  def change
    add_index :room_sessions, :room_id,
              unique: true,
              where: "closed_at IS NULL",
              name: "index_room_sessions_on_room_id_active_unique"
  end
end
