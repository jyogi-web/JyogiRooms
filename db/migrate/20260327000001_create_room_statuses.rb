class CreateRoomStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :room_statuses do |t|
      t.references :room, null: false, foreign_key: true, index: { unique: true }
      t.boolean :is_open, null: false, default: false
      t.datetime :opened_at
      t.references :opened_by, foreign_key: { to_table: :users }, index: true
      t.integer :occupant_count, null: false, default: 0
      t.jsonb :occupants, null: false, default: []

      t.timestamps
    end
  end
end
