# frozen_string_literal: true

# jyogi-auth認証処理用コンサーン
module JyogiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  # 現在ログイン中のユーザーを取得
  # @return [User, nil]
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = find_user_from_session
  end

  # ユーザーがログイン済みかどうか
  # @return [Boolean]
  def user_signed_in?
    current_user.present?
  end

  # 認証必須処理(ログインしていない場合の処理)
  def authenticate_user!
    return if user_signed_in?

    # API以外へのアクセスの場合はログインページにリダイレクト
    if !request.path.start_with?("/api/")
      store_location_for_return
      redirect_to "/auth/login"
    else
      # APIの場合は401 JSONレスポンス
      render json: { error: "認証が必要です。" }, status: :unauthorized
    end
  end

  # リダイレクト先URLをセッションに保存
  def store_location_for_return
    # GETリクエストかつXHRでない場合のみ保存
    if request.get? && !request.xhr?
      # 相対パスのみを保存し、外部URLへのリダイレクトを防ぐ
      path = request.fullpath
      return if path.bytesize > 2048
      return if path.match?(/[\r\n]/) || path.include?("\\")
      return unless path.start_with?("/") && !path.start_with?("//") && !path.start_with?("/\\")
      return if path == "/auth" || path.start_with?("/auth/")

      session[:return_to] = path
    end
  end

  # セッションからユーザーを取得
  def find_user_from_session
    access_token_id = session[:access_token_id]
    return nil unless access_token_id

    access_token = AccessToken.find_by(id: access_token_id)
    return nil unless access_token&.active?

    user = access_token.user
    unless user
      sign_out
      return nil
    end

    # キャッシュが古い場合は再同期
    sync_user_if_needed(user, access_token)
    user
  end

  # 必要に応じてユーザー情報を再同期
  def sync_user_if_needed(user, access_token)
    return if user.cache_fresh?

    begin
      user_info = JyogiAuthClient.fetch_user_info(access_token: access_token.token)
      unless user.sync_from_jyogi_auth(user_info)
        Rails.logger.warn "Failed to persist synced user info: #{user.errors.full_messages.join(', ')}"
      end
    rescue JyogiAuthClient::Error => e
      Rails.logger.warn "Failed to sync user info: #{e.message}"
      # 同期失敗してもキャッシュされた情報で継続
    end
  end

  # ログイン処理（AccessTokenレコードを作成してセッションにIDを保存）
  def sign_in(user, jyogi_access_token)
    # 既存のアクティブなトークンを失効
    user.access_tokens.active.update_all(revoked: true)

    # 新しいトークンを作成
    access_token = AccessToken.create_for_user(
      user: user,
      token_value: jyogi_access_token
    )

    session[:access_token_id] = access_token.id
    @current_user = user
  end

  # ログアウト処理
  def sign_out
    access_token_id = session[:access_token_id]
    if access_token_id
      access_token = AccessToken.find_by(id: access_token_id)
      access_token&.revoke!
    end

    reset_session
    @current_user = nil
  end
end
