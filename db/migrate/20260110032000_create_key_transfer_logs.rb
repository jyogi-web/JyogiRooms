class CreateKeyTransferLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :key_transfer_logs do |t|
      t.references :from_user, null: false, foreign_key: { to_table: :users }, index: true
      t.references :to_user, null: false, foreign_key: { to_table: :users }, index: true
      t.references :room, null: false, foreign_key: true, index: false
      t.timestamps
    end

    add_index :key_transfer_logs, :created_at
    add_index :key_transfer_logs, %i[room_id created_at]
  end
end
