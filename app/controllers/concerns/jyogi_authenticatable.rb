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

  # 認証必須処理（ログインしていない場合は401エラー）
  def authenticate_user!
    return if user_signed_in?

    render json: { error: "認証が必要です。" }, status: :unauthorized
  end

  # セッションからユーザーを取得
  def find_user_from_session
    user_id = session[:user_id]
    return nil unless user_id

    user = User.find_by(id: user_id)
    return nil unless user

    # キャッシュが古い場合は再同期
    sync_user_if_needed(user)
    user
  end

  # 必要に応じてユーザー情報を再同期
  def sync_user_if_needed(user)
    return if user.cache_fresh?

    access_token = session[:access_token]
    return unless access_token

    begin
      user_info = JyogiAuthClient.fetch_user_info(access_token: access_token)
      user.sync_from_jyogi_auth(user_info)
    rescue JyogiAuthClient::Error => e
      Rails.logger.warn "Failed to sync user info: #{e.message}"
      # 同期失敗してもキャッシュされた情報で継続
    end
  end

  # ログイン処理（セッションにユーザーIDとトークンを保存）
  def sign_in(user, access_token)
    session[:user_id] = user.id
    session[:access_token] = access_token
    @current_user = user
  end

  # ログアウト処理
  def sign_out
    session.delete(:user_id)
    session.delete(:access_token)
    @current_user = nil
  end
end
