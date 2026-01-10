class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include JyogiAuthenticatable

  # 認証をオプショナルにする（デフォルトでは認証不要）
  skip_before_action :authenticate_user!, raise: false

  # ビューでもcurrent_userを使えるようにする
  helper_method :current_user, :user_signed_in?
end
