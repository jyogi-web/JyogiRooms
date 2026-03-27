class Room < ApplicationRecord
  has_many :keys, dependent: :restrict_with_error
  has_many :key_transfer_logs, dependent: :restrict_with_error
  has_many :room_visits, dependent: :restrict_with_error
  has_many :room_sessions, dependent: :restrict_with_error
  has_one :room_status, dependent: :destroy

  validates :name, presence: true
  validates :room_number, presence: true, uniqueness: true

  after_create :create_room_status!

  private

  def create_room_status!
    RoomStatus.create!(room: self)
  end
end
