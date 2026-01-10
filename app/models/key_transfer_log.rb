class KeyTransferLog < ApplicationRecord
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"
  belongs_to :room

  validate :users_must_be_different

  private

  def users_must_be_different
    if from_user_id.present? && from_user_id == to_user_id
      errors.add(:to_user_id, "cannot be the same as from_user")
    end
  end
end
