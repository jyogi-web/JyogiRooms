# frozen_string_literal: true

class AppUpdate < ApplicationRecord
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validates :released_on, presence: true
end
