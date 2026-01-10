class User < ApplicationRecord
  has_many :reservations

  # Validations
  validates :jyogi_user_id, uniqueness: true, allow_nil: true, length: { maximum: 36 }
  validates :discord_id, uniqueness: true, allow_nil: true

  # jyogi-authから取得したユーザー情報で同期
  # @param user_info [Hash] jyogi-authから取得したユーザー情報
  # @return [Boolean] 同期成功かどうか
  def sync_from_jyogi_auth(user_info)
    update(
      jyogi_user_id: user_info['id'],
      discord_id: user_info['discord_id'],
      username: user_info['username'],
      display_name: user_info['display_name'],
      avatar_url: user_info['avatar_url'],
      guild_roles: user_info['guild_roles'] || {},
      guild_nickname: user_info['guild_nickname'],
      last_synced_at: Time.current
    )
  end

  # キャッシュが新鮮かどうかをチェック（5分以内）
  # @return [Boolean] キャッシュが有効かどうか
  def cache_fresh?
    last_synced_at.present? && last_synced_at > 5.minutes.ago
  end

  # jyogi-authと同期済みかどうか
  # @return [Boolean] 同期済みかどうか
  def synced_with_jyogi_auth?
    jyogi_user_id.present?
  end
end
