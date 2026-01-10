class CreateKeyTransferLogs < ActiveRecord::Migration[7.0]
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
  end
end