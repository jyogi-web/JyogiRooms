class CreateRolesAndAddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :roles, :name, unique: true

    add_reference :users, :role, foreign_key: { to_table: :roles }
  end
end
