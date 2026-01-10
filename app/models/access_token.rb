# frozen_string_literal: true

# jyogi-auth アクセストークン管理
class AccessToken < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # スコープ
  scope :active, -> { where(revoked: false).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :revoked, -> { where(revoked: true) }

  # トークンが有効かどうか
  # @return [Boolean]
  def active?
    !revoked? && !expired?
  end

  # トークンが期限切れかどうか
  # @return [Boolean]
  def expired?
    expires_at <= Time.current
  end

  # トークンを失効させる
  # @return [Boolean]
  def revoke!
    update!(revoked: true)
  end

  # セキュアなランダムトークンを生成
  # @return [String]
  def self.generate_token
    SecureRandom.urlsafe_base64(32)
  end

  # トークンを作成（デフォルトで24時間有効）
  # @param user [User] ユーザー
  # @param token_value [String] jyogi-authのアクセストークン
  # @param expires_in [Integer] 有効期限（秒）
  # @return [AccessToken]
  def self.create_for_user(user:, token_value:, expires_in: 24.hours)
    create!(
      user: user,
      token: token_value,
      expires_at: Time.current + expires_in
    )
  end

  # 期限切れトークンをクリーンアップ
  def self.cleanup_expired
    expired.delete_all
  end
end
