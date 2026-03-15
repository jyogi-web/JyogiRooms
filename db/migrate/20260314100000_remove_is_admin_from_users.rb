class RemoveIsAdminFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :is_admin, :boolean, default: false, null: false
  end
end
