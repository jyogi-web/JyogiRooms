class CreateRolesAndAddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false

      t.timestamps
      t.index :name, unique: true
    end

    add_reference :users, :role, foreign_key: { to_table: :roles }
  end
end
