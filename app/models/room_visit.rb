# frozen_string_literal: true

class RoomVisit < ApplicationRecord
  belongs_to :room
  belongs_to :user

  validates :entered_at, presence: true
  validates :source, presence: true, inclusion: { in: %w[nfc web forced room_close] }

  scope :active, -> { where(exited_at: nil) }
  scope :for_room, ->(room) { where(room: room) }
  scope :for_user, ->(user) { where(user: user) }
end
