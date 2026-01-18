class CreateRolesAndAddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    # rolesテーブルが存在しない場合のみ作成
    unless table_exists?(:roles)
      create_table :roles do |t|
        t.string :name, null: false

        t.timestamps
      end
    end

    # rolesテーブルのユニークインデックスを確認・追加
    if table_exists?(:roles) && !index_exists?(:roles, :name, unique: true)
      add_index :roles, :name, unique: true
    end

    # role_idカラムが存在しない場合のみ追加（外部キーとインデックス含む）
    unless column_exists?(:users, :role_id)
      add_reference :users, :role, foreign_key: { to_table: :roles }
    else
      # カラムは存在するが外部キーが無い場合
      unless foreign_key_exists?(:users, :roles)
        add_foreign_key :users, :roles, column: :role_id
      end

      # カラムは存在するがインデックスが無い場合
      unless index_exists?(:users, :role_id)
        add_index :users, :role_id
      end
    end
  end
end
