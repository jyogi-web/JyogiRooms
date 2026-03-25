# frozen_string_literal: true

class NfcRegistrationRequest < ApplicationRecord
  belongs_to :user

  validates :expires_at, presence: true
  validate :no_other_pending_request, on: :create

  scope :pending, -> { where(card_uid: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def pending?
    card_uid.nil? && !expired?
  end

  def completed?
    card_uid.present?
  end

  private

  def no_other_pending_request
    if NfcRegistrationRequest.pending.exists?
      errors.add(:base, "他のユーザーが登録中です")
    end
  end
end
