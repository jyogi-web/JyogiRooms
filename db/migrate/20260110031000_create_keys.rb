class CreateKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :keys do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :room, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end
  end
end
