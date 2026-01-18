# frozen_string_literal: true

module JyogiAuth
  class User
    attr_reader :id, :discord_id, :username, :display_name, :avatar_url,
                :guild_roles, :guild_nickname, :created_at, :updated_at

    def initialize(attributes)
      @id = attributes["id"] || attributes[:id]
      @discord_id = attributes["discord_id"] || attributes[:discord_id]
      @username = attributes["username"] || attributes[:username]
      @display_name = attributes["display_name"] || attributes[:display_name]
      @avatar_url = attributes["avatar_url"] || attributes[:avatar_url]
      @guild_roles = attributes["guild_roles"] || attributes[:guild_roles] || {}
      @guild_nickname = attributes["guild_nickname"] || attributes[:guild_nickname]
      @created_at = parse_time(attributes["created_at"] || attributes[:created_at])
      @updated_at = parse_time(attributes["updated_at"] || attributes[:updated_at])
    end

    # JyogiAuth APIから全ユーザーを取得（キャッシュ付き）
    # @param access_token [String] 認証トークン
    # @param cache [Boolean] キャッシュを使用するか（デフォルト: true）
    # @return [Array<JyogiAuth::User>]
    def self.all(access_token:, cache: true)
      raise ArgumentError, "access_token cannot be nil" if access_token.nil?

      if cache
        cache_key = cache_key_for_token(access_token)
        Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
          fetch_all_from_api(access_token)
        end
      else
        fetch_all_from_api(access_token)
      end
    end

    # APIから全ユーザーを取得（内部メソッド）
    # @param access_token [String] 認証トークン
    # @return [Array<JyogiAuth::User>]
    def self.fetch_all_from_api(access_token)
      response = JyogiAuthClient.fetch_users(access_token: access_token) || {}
      users_data = response["users"] || response[:users] || []
      users_data.map { |user_attrs| new(user_attrs) }
    end
    private_class_method :fetch_all_from_api

    # access_tokenに基づいてキャッシュキーを生成
    # トークンのハッシュを使用して、異なるトークン間でキャッシュが共有されないようにする
    # @param access_token [String] 認証トークン
    # @return [String] キャッシュキー
    def self.cache_key_for_token(access_token)
      token_hash = Digest::SHA256.hexdigest(access_token)[0, 16]
      "jyogi_auth_users:#{token_hash}"
    end
    private_class_method :cache_key_for_token

    # JyogiAuth APIから特定のユーザーを取得
    # @param id [String] JyogiAuthのユーザーID
    # @param access_token [String] 認証トークン
    # @return [JyogiAuth::User, nil]
    # @raise [JyogiAuthClient::AuthenticationError] トークンが無効な場合（再認証が必要）
    def self.find(id, access_token:)
      response = JyogiAuthClient.fetch_user_by_id(access_token: access_token, user_id: id)
      new(response) if response
    rescue JyogiAuthClient::AuthenticationError
      # 認証エラーは再認証が必要なため、呼び出し元に伝播させる
      raise
    rescue JyogiAuthClient::NetworkError, JyogiAuthClient::ValidationError => e
      Rails.logger.warn "Failed to fetch JyogiAuth user #{id}: #{e.message}"
      nil
    end

    # ローカルDBのUserモデルと対応するか確認
    # @param local_user [User] ローカルのUserモデル
    # @return [Boolean]
    def matches_local_user?(local_user)
      local_user.jyogi_user_id == @id
    end

    # 表示名を取得（guild_nickname > display_name > username の優先順位）
    # @return [String]
    def display_name_with_fallback
      guild_nickname.presence || display_name.presence || username
    end

    # JSON形式に変換
    # @return [Hash]
    def as_json(options = {})
      {
        id: @id,
        discord_id: @discord_id,
        username: @username,
        display_name: @display_name,
        avatar_url: @avatar_url,
        guild_roles: @guild_roles,
        guild_nickname: @guild_nickname,
        created_at: @created_at,
        updated_at: @updated_at
      }
    end

    # キャッシュの手動クリア
    # @param access_token [String] 認証トークン(特定のトークンのキャッシュのみをクリア)
    def self.clear_cache(access_token:)
      raise ArgumentError, "access_token cannot be nil" if access_token.nil?

      cache_key = cache_key_for_token(access_token)
      Rails.cache.delete(cache_key)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(String) ? Time.zone.parse(value) : value
    rescue ArgumentError
      nil
    end
  end
end
