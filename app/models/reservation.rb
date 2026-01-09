class Reservation < ApplicationRecord
  belongs_to :user

  validates :start_at, presence: true
  validates :end_at, presence: true
end
