# frozen_string_literal: true

require "test_helper"

class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  # ====================
  # 未認証時のテスト
  # ====================
  test "me without authentication returns 401" do
    get "/api/users/me"
    assert_response :unauthorized
  end

  test "index without authentication returns 401" do
    get "/api/users"
    assert_response :unauthorized
    assert_equal "認証が必要です。", response.parsed_body["error"]
  end

  test "show without authentication returns 401" do
    get "/api/users/#{users(:one).id}"
    assert_response :unauthorized
  end

  test "create without authentication returns 401" do
    post "/api/users"
    assert_response :unauthorized
  end

  test "update without authentication returns 401" do
    put "/api/users/#{users(:one).id}"
    assert_response :unauthorized
  end

  test "destroy without authentication returns 401" do
    delete "/api/users/#{users(:one).id}"
    assert_response :unauthorized
  end

  # ====================
  # 認証済み時のテスト
  # ====================
  test "me with authentication returns success" do
    sign_in_as(users(:one))
    get "/api/users/me"
    assert_response :success
    assert response.parsed_body.key?("user")
  end

  test "index with authentication returns success" do
    sign_in_as(users(:one))
    get "/api/users"
    assert_response :success
    assert response.parsed_body.key?("users")
  end

  test "show with authentication returns success" do
    user = users(:one)
    sign_in_as(user)
    get "/api/users/#{user.id}"
    assert_response :success
    assert response.parsed_body.key?("user")
  end

  test "show with authentication returns 404 for non-existent user" do
    sign_in_as(users(:one))
    get "/api/users/999999"
    assert_response :not_found
  end

  test "create with authentication returns 405 (not implemented)" do
    sign_in_as(users(:one))
    post "/api/users"
    assert_response :method_not_allowed
  end

  test "update with authentication returns 405 (not implemented)" do
    sign_in_as(users(:one))
    put "/api/users/#{users(:one).id}"
    assert_response :method_not_allowed
  end

  test "destroy with authentication returns 405 (not implemented)" do
    sign_in_as(users(:one))
    delete "/api/users/#{users(:one).id}"
    assert_response :method_not_allowed
  end
end
