class CreateAppUpdates < ActiveRecord::Migration[8.0]
  def change
    create_table :app_updates do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.date :released_on, null: false

      t.timestamps
    end

    add_index :app_updates, :released_on
  end
end
