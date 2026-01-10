class CreateKeyTransferLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :key_transfer_logs do |t|
      t.bigint :from_user_id, null: false
      t.bigint :to_user_id, null: false
      t.bigint :room_id, null: false
      t.timestamps
    end
    add_foreign_key :key_transfer_logs, :users, column: :from_user_id
    add_foreign_key :key_transfer_logs, :users, column: :to_user_id
    add_foreign_key :key_transfer_logs, :rooms

    add_index :key_transfer_logs, :from_user_id
    add_index :key_transfer_logs, :to_user_id
    add_index :key_transfer_logs, :room_id
    add_index :key_transfer_logs, :created_at
    add_index :key_transfer_logs, %i[room_id created_at]
  end
end
