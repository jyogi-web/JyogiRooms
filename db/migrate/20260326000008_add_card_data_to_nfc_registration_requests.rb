# frozen_string_literal: true

class AddCardDataToNfcRegistrationRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :nfc_registration_requests, :student_id, :string
    add_column :nfc_registration_requests, :student_name, :string
  end
end
