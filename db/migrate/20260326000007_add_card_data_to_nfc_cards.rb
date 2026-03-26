# frozen_string_literal: true

class AddCardDataToNfcCards < ActiveRecord::Migration[8.1]
  def change
    add_column :nfc_cards, :student_id, :string
    add_column :nfc_cards, :student_name, :string
  end
end
