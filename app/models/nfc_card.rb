# frozen_string_literal: true

class NfcCard < ApplicationRecord
  belongs_to :user

  validates :card_uid, presence: true, uniqueness: true
end
