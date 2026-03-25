# frozen_string_literal: true

class RoomSession < ApplicationRecord
  belongs_to :room
  belongs_to :opened_by, class_name: "User"
  belongs_to :closed_by, class_name: "User", optional: true

  validates :opened_at, presence: true

  scope :active, -> { where(closed_at: nil) }
  scope :for_room, ->(room) { where(room: room) }
end
