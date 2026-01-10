class Key < ApplicationRecord
  belongs_to :user
  belongs_to :room

  validates :room_id, uniqueness: true
end