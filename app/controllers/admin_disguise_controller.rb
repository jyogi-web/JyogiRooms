# frozen_string_literal: true

class AdminDisguiseController < ApplicationController
  before_action :require_real_admin!

  # POST /admin_disguise/toggle
  def toggle
    session[:admin_disguise] = !session[:admin_disguise]
    redirect_back fallback_location: root_path
  end

  private

  def require_real_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "権限がありません"
    end
  end
end
