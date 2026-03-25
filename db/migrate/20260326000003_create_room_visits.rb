# frozen_string_literal: true

class CreateRoomVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :room_visits do |t|
      t.references :room, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :entered_at, null: false
      t.datetime :exited_at
      t.string :source, null: false, default: "nfc"

      t.timestamps
    end

    add_index :room_visits, [:user_id, :exited_at]
    add_index :room_visits, [:room_id, :exited_at]
  end
end
