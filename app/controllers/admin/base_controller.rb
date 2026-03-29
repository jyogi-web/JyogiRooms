class Admin::BaseController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    unless effective_admin?
      redirect_to root_path, alert: "権限がありません"
    end
  end
end
