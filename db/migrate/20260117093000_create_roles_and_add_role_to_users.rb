class CreateRolesAndAddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    # rolesテーブルが存在しない場合のみ作成
    unless table_exists?(:roles)
      create_table :roles do |t|
        t.string :name, null: false

        t.timestamps
      end
      add_index :roles, :name, unique: true
    end

    # role_idカラムが存在しない場合のみ追加
    unless column_exists?(:users, :role_id)
      add_reference :users, :role, foreign_key: { to_table: :roles }
    end
  end
end
