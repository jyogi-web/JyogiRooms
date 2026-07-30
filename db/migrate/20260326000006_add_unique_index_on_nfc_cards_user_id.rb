# frozen_string_literal: true

class AddUniqueIndexOnNfcCardsUserId < ActiveRecord::Migration[8.1]
  def change
    remove_index :nfc_cards, :user_id
    add_index :nfc_cards, :user_id, unique: true
  end
end
