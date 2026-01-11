class AddJyogiAuthFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :jyogi_user_id, :string, limit: 36
    add_index :users, :jyogi_user_id, unique: true
    add_column :users, :discord_id, :string
    add_index :users, :discord_id, unique: true
    add_column :users, :username, :string
    add_column :users, :display_name, :string
    add_column :users, :avatar_url, :string
    add_column :users, :guild_roles, :jsonb, default: {}
    add_column :users, :guild_nickname, :string
    add_column :users, :last_synced_at, :datetime
  end
end
