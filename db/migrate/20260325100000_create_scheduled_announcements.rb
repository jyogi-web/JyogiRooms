# frozen_string_literal: true

class CreateScheduledAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_announcements do |t|
      t.text :message, null: false
      t.integer :hour, null: false, default: 20
      t.integer :minute, null: false, default: 0
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
  end
end
