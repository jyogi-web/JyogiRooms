class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include JyogiAuthenticatable

  # アプリ全体へのアクセス記録（category: "app"）。
  # 未ログイン（authenticate_user! のリダイレクト後もコールバックは継続する）は
  # log_app_access 内のガードで弾く。
  before_action :log_app_access

  # ビューでもcurrent_userを使えるようにする
  helper_method :current_user, :user_signed_in?, :effective_admin?, :effective_admin_or_manager?

  # 管理者偽装モード中はfalseを返す（実際のDB権限は変更しない）
  def effective_admin?
    current_user&.admin? && !session[:admin_disguise]
  end

  def effective_admin_or_manager?
    current_user&.manager? || effective_admin?
  end

  private

  # メンバー画面（HTML GET）へのアクセスを「アプリ全体へのアクセス」として記録する。
  # - 画面種別は問わない（ダッシュボード・予約・鍵・部室状況など全画面が対象）
  # - API / 管理画面 / 認証 / ヘルスチェックは対象外
  # - 5分以内の再アクセスは RoomViewLogger / Worker 側の throttle で間引かれる
  #   （＝「利用セッション数」的な指標になる）
  APP_ACCESS_EXCLUDED_PREFIXES = %w[/api /admin /auth /up].freeze

  def log_app_access
    return unless request.get? && request.format.html?
    return if current_user.blank?
    return if app_access_excluded_path?

    RoomViewLogger.log_web_view(current_user, category: "app")
  end

  def app_access_excluded_path?
    path = request.path
    APP_ACCESS_EXCLUDED_PREFIXES.any? do |prefix|
      path == prefix || path.start_with?("#{prefix}/")
    end
  end
end
