class Role < ApplicationRecord
  ADMIN = "admin".freeze

  has_many :users, dependent: :nullify, inverse_of: :role

  validates :name, presence: true, uniqueness: true
end
