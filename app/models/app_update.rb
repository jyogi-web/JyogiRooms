# frozen_string_literal: true

class AppUpdate < ApplicationRecord
  validates :title, presence: true
  validates :description, presence: true
  validates :released_on, presence: true
end
