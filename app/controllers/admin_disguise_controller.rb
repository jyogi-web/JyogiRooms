# frozen_string_literal: true

class AdminDisguiseController < ApplicationController
  before_action :require_real_admin!

  # POST /admin_disguise/toggle
  def toggle
    session[:admin_disguise] = !session[:admin_disguise]

    if session[:admin_disguise]
      # 偽装ON: 管理画面にいると権限エラーになるためルートに遷移
      redirect_to root_path
    else
      redirect_back fallback_location: root_path
    end
  end

  private

  def require_real_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "権限がありません"
    end
  end
end
