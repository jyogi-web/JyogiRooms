class CreateMasterData < ActiveRecord::Migration[8.1]
  def up
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

    # デフォルトロールを作成
    Role.find_or_create_by!(name: "admin")
    Role.find_or_create_by!(name: "member")

    # 部屋マスターデータ
    rooms_data = [
      { name: "第１部室", room_number: "322" },
      { name: "第２部室", room_number: "321" },
      { name: "第３部室", room_number: "224" }
    ]

    rooms_data.each do |room_data|
      room = Room.find_or_create_by!(room_number: room_data[:room_number]) do |r|
        r.name = room_data[:name]
      end

      # 各部屋に5本の鍵を作成（既存分を除く）
      existing_keys_count = Key.where(room_id: room.id, user_id: nil).count
      missing_keys_count = 5 - existing_keys_count

      missing_keys_count.times do
        Key.create!(room_id: room.id, user_id: nil)
      end
    end
  end

  def down
    # Remove seeded data first
    Role.where(name: ["admin", "member"]).destroy_all
    Room.where(room_number: ["322", "321", "224"]).destroy_all

    # Remove DDL changes in reverse order
    if foreign_key_exists?(:users, :roles)
      remove_foreign_key :users, :roles
    end

    if column_exists?(:users, :role_id)
      remove_reference :users, :role
    end

    if table_exists?(:roles)
      drop_table :roles
    end
  end
end
