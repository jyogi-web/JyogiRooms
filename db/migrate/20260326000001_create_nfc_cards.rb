# frozen_string_literal: true

class CreateNfcCards < ActiveRecord::Migration[8.1]
  def change
    create_table :nfc_cards do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :card_uid, null: false

      t.timestamps
    end

    add_index :nfc_cards, :card_uid, unique: true
  end
end
