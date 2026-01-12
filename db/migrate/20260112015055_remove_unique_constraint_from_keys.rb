class RemoveUniqueConstraintFromKeys < ActiveRecord::Migration[8.1]
  def change
    remove_index :keys, :room_id
    add_index :keys, [:room_id, :user_id], unique: true
    add_index :keys, :room_id
  end
end
