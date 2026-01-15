require "test_helper"

class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_users_index_url
    assert_response :success
  end

  test "should get show" do
    user = users(:one)
    get api_user_url(id: user.id)
    assert_response :success
  end

  # TODO: コードが実装されたら有効化する
  # test "should get create" do
  #   get api_users_create_url
  #   assert_response :success
  # end

  # test "should get update" do
  #   get api_users_update_url
  #   assert_response :success
  # end

  # test "should get destroy" do
  #   get api_users_destroy_url
  #   assert_response :success
  # end
  
  test "create returns 405" do
    post "/api/users"
    assert_response :method_not_allowed
  end

  test "update returns 405" do
    put "/api/users/1"
    assert_response :method_not_allowed
  end

  test "destroy returns 405" do
    delete "/api/users/1"
    assert_response :method_not_allowed
  end
end
