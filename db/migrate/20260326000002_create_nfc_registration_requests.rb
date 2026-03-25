# frozen_string_literal: true

class CreateNfcRegistrationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :nfc_registration_requests do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :card_uid
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :nfc_registration_requests, :expires_at
  end
end
