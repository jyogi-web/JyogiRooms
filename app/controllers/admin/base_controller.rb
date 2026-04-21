class Admin::BaseController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    unless effective_admin_or_manager?
      redirect_to root_path, alert: "権限がありません"
    end
  end

  def require_developer_admin!
    unless effective_admin?
      redirect_to admin_root_path, alert: "この機能はadminのみ利用できます"
    end
  end
end
