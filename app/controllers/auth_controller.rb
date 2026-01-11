# frozen_string_literal: true

# OAuth2認証フローコントローラー
class AuthController < ApplicationController
  include ErrorRenderable

  skip_before_action :verify_authenticity_token, only: [ :callback ]
  skip_before_action :authenticate_user!

  def login_params
    params.permit(:return_to)
  end

  # GET /auth/login
  # OAuth2認可フローを開始
  def login
    # return_toパラメータがあればセッションに保存
    if login_params[:return_to].present?
      session[:return_to] = sanitize_return_to (login_params[:return_to])
    end

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

      # ログイン処理（AccessTokenレコード作成とセッション保存）
      sign_in(user, access_token)

      # return_toがあればそこにリダイレクト、なければデフォルト
      redirect_url = consume_return_to || success_redirect_url
      redirect_to redirect_url, allow_other_host: true
    rescue JyogiAuthClient::Error => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to error_redirect_url(e.message), allow_other_host: true
    ensure
      # oauth_stateを確実にクリア（成功/失敗問わず）
      session.delete(:oauth_state)
    end
  end

  # DELETE /auth/logout
  # ログアウト処理
  def logout
    access_token_id = session[:access_token_id]
    access_token_record = AccessToken.find_by(id: access_token_id) if access_token_id

    begin
      # jyogi-auth側でトークンを無効化
      if access_token_record
        JyogiAuthClient.logout(access_token: access_token_record.token)
      end
    rescue JyogiAuthClient::Error => e
      Rails.logger.warn "Logout error (ignored): #{e.message}"
      # ログアウトエラーは無視してセッションとDBトークンをクリア
    ensure
      # ローカルのログアウト処理（DBトークン失効とセッションクリア）
      sign_out

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

  # return_toを消費(取得後削除)
  def consume_return_to
    return_to = session.delete(:return_to)
    return nil unless return_to

    begin
      uri = URI.parse(return_to)
      # スキームとホストがない相対パスのみ許可
      return_to if uri.scheme.nil? && uri.host.nil? && return_to.start_with?("/") && !return_to.start_with?("//")
    rescue URI::InvalidURIError
      nil
    end
  end

  # return_toパラメータのサニタイズ
  def sanitize_return_to(url)
    return nil if url.blank?

    # プロトコル相対URLや不正なパスを除外
    return nil unless url.start_with?("/")
    return nil if url.start_with?("//") || url.start_with?("/\\")

    # パストラバーサルを含むURLを除外
    return nil if url.include?("/../") || url.include?("/./")

    # 正規化後のパスで認証フローへのリダイレクトを禁止
    begin
      normalized_path = Pathname.new(url).cleanpath.to_s
    rescue StandardError
      return nil
    end
    return nil if normalized_path.start_with?("/auth/")

    url
  end
end
