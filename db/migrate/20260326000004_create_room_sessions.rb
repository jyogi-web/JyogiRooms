# frozen_string_literal: true

class CreateRoomSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :room_sessions do |t|
      t.references :room, null: false, foreign_key: true
      t.references :opened_by, null: false, foreign_key: { to_table: :users }
      t.references :closed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :opened_at, null: false
      t.datetime :closed_at

      t.timestamps
    end

    add_index :room_sessions, [ :room_id, :closed_at ]
  end
end
