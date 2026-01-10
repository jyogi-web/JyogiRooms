class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :name, null: false
      t.string :room_number, null: false
      t.timestamps
    end
    add_index :rooms, :room_number, unique: true
  end
end
