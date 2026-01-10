class CreateAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.boolean :revoked, null: false, default: false

      t.timestamps
    end

    add_index :access_tokens, :token, unique: true
    add_index :access_tokens, [ :user_id, :revoked ]
    add_index :access_tokens, :expires_at
  end
end
