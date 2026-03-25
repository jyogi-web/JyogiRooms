# frozen_string_literal: true

class NfcCard < ApplicationRecord
  belongs_to :user

  validates :card_uid, presence: true, uniqueness: true
  validates :user_id, uniqueness: { message: "には既にカードが登録されています" }
end
