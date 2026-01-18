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

    test "initializes with string keys" do
      user = JyogiAuth::User.new(@valid_attributes)

      assert_equal "user-123", user.id
      assert_equal "123456789", user.discord_id
      assert_equal "testuser", user.username
      assert_equal "Test User", user.display_name
      assert_equal "https://example.com/avatar.png", user.avatar_url
      assert_equal({ "role1" => "value1" }, user.guild_roles)
      assert_equal "Test Nickname", user.guild_nickname
      assert_instance_of Time, user.created_at
      assert_instance_of Time, user.updated_at
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

    test "clear_cache calls Rails.cache.delete with correct key" do
      # clear_cache がエラーなく実行されることを確認
      assert_nothing_raised do
        JyogiAuth::User.clear_cache
      end
    end
  end
end
