# frozen_string_literal: true

# OAuth2認証フローコントローラー
class AuthController < ApplicationController
  include ErrorRenderable

  skip_before_action :verify_authenticity_token, only: [ :callback, :logged_out ]
  skip_before_action :authenticate_user!

  private def login_params
    params.permit(:return_to)
  end

  # GET /auth/login
  # OAuth2認可フローを開始
  def login
    # return_toパラメータがあればセッションに保存
    if login_params[:return_to].present?
      sanitized = sanitize_return_to(login_params[:return_to])
      session[:return_to] = sanitized if sanitized.present?
    end

    authorization_url = JyogiAuthClient.authorization_url
    redirect_to authorization_url, allow_other_host: true
  end

  # GET /auth/callback
  # OAuth2コールバック処理
  def callback
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

      # リダイレクト先へ遷移
      if (return_to = consume_return_to).present?
        redirect_to return_to
      else
        redirect_to success_redirect_url, allow_other_host: true
      end
    rescue JyogiAuthClient::Error => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to error_redirect_url(e.message), allow_other_host: true
    ensure
      # oauth_stateを確実にクリア（成功/失敗問わず）
      session.delete(:oauth_state)
    end
  end

  # GET /auth/logged_out
  # ログアウト完了ページ
  def logged_out
    # 既にログイン中の場合はホームにリダイレクト
    return redirect_to root_path if current_user

    render layout: false
  end

  # DELETE /auth/logout
  # ログアウト処理
  def logout
    # ローカルのログアウト処理（DBトークン失効とセッションクリア）
    sign_out

    respond_to do |format|
      # jyogi-authのログアウトページにリダイレクト（Discordセッションもクリア）
      logout_url_with_redirect = "#{JyogiAuth.configuration.logout_url}?redirect_uri=#{CGI.escape(auth_logged_out_url)}"
      format.html { redirect_to logout_url_with_redirect, allow_other_host: true }
      format.json { render json: { message: "ログアウトしました。" }, status: :ok }
    end
  end

  private

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

  # return_toパスのバリデーション・正規化（共通処理）
  def validate_return_to_path(raw)
    return nil if raw.blank?

    url = raw.strip
    return nil if url.blank?
    return nil if url.include?("\\") || url.include?("\n") || url.include?("\r")
    return nil unless url.start_with?("/")
    return nil if url.start_with?("//")

    begin
      normalized_path = Pathname.new(url).cleanpath.to_s
    rescue StandardError
      return nil
    end

    return nil unless normalized_path.start_with?("/")
    return nil if normalized_path.start_with?("/auth")

    normalized_path
  end

  # return_toを消費(取得後削除)し、バリデーション・正規化を行う
  def consume_return_to
    raw = session.delete(:return_to)
    validate_return_to_path(raw)
  end

  # return_toパラメータのサニタイズ
  def sanitize_return_to(url)
    validate_return_to_path(url)
  end
end
