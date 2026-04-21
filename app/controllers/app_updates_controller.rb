# frozen_string_literal: true

class AppUpdatesController < ApplicationController
  before_action :forbid_manager!

  def index
    @app_updates = AppUpdate.order(released_on: :desc)
  end

  private

  def forbid_manager!
    return unless current_user&.manager?

    redirect_to root_path, alert: "managerはアップデート情報を利用できません"
  end
end
