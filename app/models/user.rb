class User < ApplicationRecord
  belongs_to :role, optional: true, inverse_of: :users
  has_many :reservations
  has_many :access_tokens, dependent: :destroy
  has_many :keys, dependent: :destroy
  has_one :nfc_card, dependent: :destroy
  has_many :room_visits, dependent: :restrict_with_error
  has_many :nfc_registration_requests, dependent: :destroy

  # Callbacks
  after_create :assign_default_role
  before_save :assign_admin_role_from_env

  # Validations
  validates :jyogi_user_id, uniqueness: true, allow_nil: true, length: { maximum: 36 }
  validates :discord_id, uniqueness: true, allow_nil: true

  # jyogi-authから取得したユーザー情報で同期
  # @param user_info [Hash] jyogi-authから取得したユーザー情報
  # @return [Boolean] 同期成功かどうか
  def sync_from_jyogi_auth(user_info)
    update(
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

  # 環境変数 ADMIN_DISCORD_IDS に含まれるユーザーに管理者ロールを付与する
  # 新規作成時や同期時に呼び出される
  def assign_admin_role_from_env
    return if discord_id.blank?

    admin_ids = ENV.fetch("ADMIN_DISCORD_IDS", "").split(",").map(&:strip)
    if admin_ids.include?(discord_id)
      admin_role = Role.find_or_create_by!(name: Role::ADMIN)
      # update! ではなくオブジェクトへのアサインに留める（呼び出し元で save されるため）
      self.role = admin_role if role_id != admin_role.id
    end
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

  # ユーザーが管理者ロールを持つかどうか
  # NOTE: ループ内で呼ぶ場合は必ず User.includes(:role) を使用してN+1を防ぐこと
  # @return [Boolean] 管理者かどうか
  def admin?
    role&.name == Role::ADMIN
  end

  private

  # 新規ユーザーにデフォルトロール（member）を割り当てる
  # adminが既に設定されている場合はスキップする
  def assign_default_role
    return if role_id.present?
    update_column(:role_id, Role.find_by(name: Role::MEMBER)&.id)
  end
end
