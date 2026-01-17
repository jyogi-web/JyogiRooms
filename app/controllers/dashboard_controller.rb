class DashboardController < ApplicationController
  def index
    @reservations = Reservation.where(start_at: Time.zone.now.all_day).includes(:user).order(:start_at)
    @rooms = Room.includes(keys: :user).order(room_number: :desc)

    # 開発・テスト環境でのユーザー切り替え用
    if Rails.env.development? || Rails.env.test?
      @all_users = User.includes(:role).order(:username)
    end
  end

  def switch_user
    # 開発・テスト環境でのみ許可
    unless Rails.env.development? || Rails.env.test?
      redirect_to root_path, alert: "この機能は開発環境でのみ使用できます"
      return
    end

    user = User.find_by(id: params[:user_id])
    if user
      # 既存トークンを失効
      current_user&.access_tokens&.active&.update_all(revoked: true)

      # ダミートークンで新規ログイン
      dummy_token = "dev_token_#{SecureRandom.hex(16)}"
      access_token = AccessToken.create_for_user(user: user, token_value: dummy_token)
      session[:access_token_id] = access_token.id
      @current_user = user

      # ロール情報をセッションに保存（共通メソッド使用）
      store_user_role_in_session(user)

      redirect_to root_path, notice: "#{user.display_name} に切り替えました#{user.admin? ? ' (管理者)' : ''}"
    else
      redirect_to root_path, alert: "ユーザーが見つかりません"
    end
  end
end
