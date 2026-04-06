# frozen_string_literal: true

class AppUpdatesController < ApplicationController
  def index
    @app_updates = AppUpdate.order(released_on: :desc)
  end
end
