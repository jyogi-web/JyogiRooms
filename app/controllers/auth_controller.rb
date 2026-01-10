# frozen_string_literal: true

# OAuth2認証フローコントローラー
class AuthController < ApplicationController
  include ErrorRenderable

  skip_before_action :verify_authenticity_token, only: [ :callback ]

  # GET /auth/login
  # OAuth2認可フローを開始
  def login
    state = SecureRandom.hex(16)
    session[:oauth_state] = state

    authorization_url = JyogiAuthClient.authorization_url(state: state)
    redirect_to authorization_url, allow_other_host: true
  end

  # GET /auth/callback
  # OAuth2コールバック処理
  def callback
    # stateパラメータ検証（CSRF対策）
    unless valid_state?
      redirect_to error_redirect_url("Invalid state parameter"), allow_other_host: true
      return
    end

    code = params[:code]
    unless code
      redirect_to error_redirect_url("Authorization code not found"), allow_other_host: true
      return
    end

    begin
      # 認可コードをアクセストークンに交換
      token_response = JyogiAuthClient.exchange_code_for_token(code: code)
      access_token = token_response["access_token"]

      # アクセストークンでユーザー情報を取得
      user_info = JyogiAuthClient.fetch_user_info(access_token: access_token)

      # ユーザーを作成または更新
      user = find_or_create_user(user_info)

      # セッションに保存
      session[:user_id] = user.id
      session[:access_token] = access_token
      session.delete(:oauth_state)

      # フロントエンドにリダイレクト
      redirect_to success_redirect_url, allow_other_host: true
    rescue JyogiAuthClient::Error => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to error_redirect_url(e.message), allow_other_host: true
    end
  end

  # DELETE /auth/logout
  # ログアウト処理
  def logout
    access_token = session[:access_token]

    begin
      # jyogi-auth側でトークンを無効化
      JyogiAuthClient.logout(access_token: access_token) if access_token
    rescue JyogiAuthClient::Error => e
      Rails.logger.warn "Logout error (ignored): #{e.message}"
      # ログアウトエラーは無視してセッションをクリア
    ensure
      # セッションをクリア
      reset_session

      render json: { message: "ログアウトしました。" }, status: :ok
    end
  end

  private

  def valid_state?
    stored_state = session[:oauth_state]
    received_state = params[:state]
    stored_state.present? && received_state.present? && stored_state == received_state
  end

  def find_or_create_user(user_info)
    jyogi_user_id = user_info["id"]
    
    User.transaction do
      user = User.find_by(jyogi_user_id: jyogi_user_id)

      if user
        # 既存ユーザーの情報を更新
        user.sync_from_jyogi_auth(user_info)
        user
      else
        # 新規ユーザー作成
        User.create!(
          jyogi_user_id: user_info["id"],
          discord_id: user_info["discord_id"],
          username: user_info["username"],
          display_name: user_info["display_name"],
          avatar_url: user_info["avatar_url"],
          guild_roles: user_info["guild_roles"] || {},
          guild_nickname: user_info["guild_nickname"],
          last_synced_at: Time.current
        )
      end
    end
  end

  def success_redirect_url
    frontend_url = JyogiAuth.configuration.frontend_url
    "#{frontend_url}?auth=success"
  end

  def error_redirect_url(message)
    frontend_url = JyogiAuth.configuration.frontend_url
    encoded_message = CGI.escape(message)
    "#{frontend_url}?auth=error&message=#{encoded_message}"
  end
end
