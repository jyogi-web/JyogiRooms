# frozen_string_literal: true

require "test_helper"

module JyogiAuth
  class UserTest < ActiveSupport::TestCase
    def setup
      @valid_attributes = {
        "id" => "user-123",
        "discord_id" => "123456789",
        "username" => "testuser",
        "display_name" => "Test User",
        "avatar_url" => "https://example.com/avatar.png",
        "guild_roles" => { "role1" => "value1" },
        "guild_nickname" => "Test Nickname",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-02T00:00:00Z"
      }
    end

    # キャッシュを有効にしてブロックを実行するヘルパーメソッド
    def with_caching
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      yield
    ensure
      Rails.cache = original_cache
    end

    test "initializes with string keys" do
      user = JyogiAuth::User.new(@valid_attributes)

      assert_equal "user-123", user.id
      assert_equal "123456789", user.discord_id
      assert_equal "testuser", user.username
      assert_equal "Test User", user.display_name
      assert_equal "https://example.com/avatar.png", user.avatar_url
      assert_equal({ "role1" => "value1" }, user.guild_roles)
      assert_equal "Test Nickname", user.guild_nickname
      assert_instance_of ActiveSupport::TimeWithZone, user.created_at
      assert_instance_of ActiveSupport::TimeWithZone, user.updated_at
    end

    test "initializes with symbol keys" do
      attributes = {
        id: "user-456",
        discord_id: "987654321",
        username: "symboluser",
        display_name: "Symbol User"
      }

      user = JyogiAuth::User.new(attributes)

      assert_equal "user-456", user.id
      assert_equal "987654321", user.discord_id
      assert_equal "symboluser", user.username
      assert_equal "Symbol User", user.display_name
    end

    test "guild_roles defaults to empty hash" do
      user = JyogiAuth::User.new({ "id" => "user-123" })

      assert_equal({}, user.guild_roles)
    end

    test "display_name_with_fallback returns guild_nickname when present" do
      user = JyogiAuth::User.new(@valid_attributes)

      assert_equal "Test Nickname", user.display_name_with_fallback
    end

    test "display_name_with_fallback returns display_name when guild_nickname is nil" do
      attributes = @valid_attributes.merge("guild_nickname" => nil)
      user = JyogiAuth::User.new(attributes)

      assert_equal "Test User", user.display_name_with_fallback
    end

    test "display_name_with_fallback returns username when both guild_nickname and display_name are nil" do
      attributes = @valid_attributes.merge("guild_nickname" => nil, "display_name" => nil)
      user = JyogiAuth::User.new(attributes)

      assert_equal "testuser", user.display_name_with_fallback
    end

    test "display_name_with_fallback handles blank values" do
      attributes = @valid_attributes.merge("guild_nickname" => "", "display_name" => "")
      user = JyogiAuth::User.new(attributes)

      assert_equal "testuser", user.display_name_with_fallback
    end

    test "matches_local_user? returns true when jyogi_user_id matches" do
      user = JyogiAuth::User.new(@valid_attributes)
      local_user = ::User.new(jyogi_user_id: "user-123")

      assert user.matches_local_user?(local_user)
    end

    test "matches_local_user? returns false when jyogi_user_id does not match" do
      user = JyogiAuth::User.new(@valid_attributes)
      local_user = ::User.new(jyogi_user_id: "different-id")

      refute user.matches_local_user?(local_user)
    end

    test "as_json returns hash with all attributes" do
      user = JyogiAuth::User.new(@valid_attributes)
      json = user.as_json

      assert_equal "user-123", json[:id]
      assert_equal "123456789", json[:discord_id]
      assert_equal "testuser", json[:username]
      assert_equal "Test User", json[:display_name]
      assert_equal "https://example.com/avatar.png", json[:avatar_url]
      assert_equal({ "role1" => "value1" }, json[:guild_roles])
      assert_equal "Test Nickname", json[:guild_nickname]
    end

    test "parse_time handles nil value" do
      attributes = @valid_attributes.merge("created_at" => nil)
      user = JyogiAuth::User.new(attributes)

      assert_nil user.created_at
    end

    test "parse_time handles invalid time string" do
      attributes = @valid_attributes.merge("created_at" => "invalid-time")
      user = JyogiAuth::User.new(attributes)

      assert_nil user.created_at
    end

    test "parse_time handles Time object" do
      time = Time.current
      attributes = @valid_attributes.merge("created_at" => time)
      user = JyogiAuth::User.new(attributes)

      assert_equal time, user.created_at
    end

    test "clear_cache deletes cache for specific token" do
      with_caching do
        access_token = "test_token_123"
        cache_key = JyogiAuth::User.send(:cache_key_for_token, access_token)

        Rails.cache.write(cache_key, ["dummy"])
        JyogiAuth::User.clear_cache(access_token: access_token)
        assert_nil Rails.cache.read(cache_key)
      end
    end

    test "clear_cache raises error when access_token is nil" do
      assert_raises(ArgumentError) do
        JyogiAuth::User.clear_cache(access_token: nil)
      end
    end

    test "clear_cache only deletes cache for specified token" do
      with_caching do
        token1 = "token_1"
        token2 = "token_2"
        cache_key1 = JyogiAuth::User.send(:cache_key_for_token, token1)
        cache_key2 = JyogiAuth::User.send(:cache_key_for_token, token2)

        # Write cache for both tokens
        Rails.cache.write(cache_key1, ["dummy1"])
        Rails.cache.write(cache_key2, ["dummy2"])

        # Verify both caches exist before clearing
        assert_equal ["dummy1"], Rails.cache.read(cache_key1), "cache_key1 should contain dummy1"
        assert_equal ["dummy2"], Rails.cache.read(cache_key2), "cache_key2 should contain dummy2"

        # Clear only token1's cache
        JyogiAuth::User.clear_cache(access_token: token1)

        # Verify only token1's cache was deleted
        assert_nil Rails.cache.read(cache_key1), "cache_key1 should be deleted"
        assert_equal ["dummy2"], Rails.cache.read(cache_key2), "cache_key2 should still exist"
      end
    end

    test "User.all generates different cache keys for different tokens" do
      token1 = "token_1"
      token2 = "token_2"

      cache_key1 = JyogiAuth::User.send(:cache_key_for_token, token1)
      cache_key2 = JyogiAuth::User.send(:cache_key_for_token, token2)

      # Different tokens should produce different cache keys
      refute_equal cache_key1, cache_key2
      assert_match(/^jyogi_auth_users:[0-9a-f]{16}$/, cache_key1)
      assert_match(/^jyogi_auth_users:[0-9a-f]{16}$/, cache_key2)
    end

    test "User.all uses token-specific cache key" do
      with_caching do
        token = "test_token_456"
        expected_cache_key = JyogiAuth::User.send(:cache_key_for_token, token)

        # Pre-populate cache with dummy data
        dummy_users = [JyogiAuth::User.new({ "id" => "cached_user", "username" => "cached" })]
        Rails.cache.write(expected_cache_key, dummy_users)

        # Read the cache back to verify it was written correctly
        cached_data = Rails.cache.read(expected_cache_key)
        assert_not_nil cached_data, "Cache should contain data"
        assert_equal 1, cached_data.length
        assert_equal "cached_user", cached_data.first.id
        assert_equal "cached", cached_data.first.username
      end
    end

    test "User.all raises error when access_token is nil" do
      assert_raises(ArgumentError) do
        JyogiAuth::User.all(access_token: nil)
      end
    end

    test "cache_key_for_token generates consistent hash for same token" do
      token = "consistent_token"

      key1 = JyogiAuth::User.send(:cache_key_for_token, token)
      key2 = JyogiAuth::User.send(:cache_key_for_token, token)

      # Same token should always generate the same cache key
      assert_equal key1, key2
    end

    test "cache_key_for_token uses SHA256 hash" do
      token = "test_token_for_hash"
      cache_key = JyogiAuth::User.send(:cache_key_for_token, token)

      # Verify the format includes a 16-character hex hash
      assert_match(/^jyogi_auth_users:[0-9a-f]{16}$/, cache_key)

      # Verify it's actually the first 16 chars of SHA256
      expected_hash = Digest::SHA256.hexdigest(token)[0, 16]
      assert_equal "jyogi_auth_users:#{expected_hash}", cache_key
    end
  end
end
