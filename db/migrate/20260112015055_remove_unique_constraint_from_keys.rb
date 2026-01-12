class RemoveUniqueConstraintFromKeys < ActiveRecord::Migration[8.1]
  def up
    remove_index :keys, :room_id
    add_index :keys, [ :room_id, :user_id ], unique: true
    add_index :keys, :room_id
  end

  def down
    remove_index :keys, :room_id
    remove_index :keys, [ :room_id, :user_id ]
    add_index :keys, :room_id, unique: true
  end
end
