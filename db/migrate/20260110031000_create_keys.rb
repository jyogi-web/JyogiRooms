class CreateKeys < ActiveRecord::Migration[7.0]
  def change
    create_table :keys do |t|
      t.bigint :user_id, null: false
      t.bigint :room_id, null: false
      t.timestamps
    end
    add_foreign_key :keys, :users
    add_foreign_key :keys, :rooms
    add_index :keys, :room_id, unique: true
  end
end
