class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include JyogiAuthenticatable

  # ビューでもcurrent_userを使えるようにする
  helper_method :current_user, :user_signed_in?, :effective_admin?

  # 管理者偽装モード中はfalseを返す（実際のDB権限は変更しない）
  def effective_admin?
    current_user&.admin? && !session[:admin_disguise]
  end
end
