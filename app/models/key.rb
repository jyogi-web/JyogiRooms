class Key < ApplicationRecord
  belongs_to :user
  belongs_to :room

  validates :room_id, uniqueness: { scope: :user_id, message: "you already have a key for this room" }
end
