require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get index" do
    sign_in_as(@user)
    get root_url
    assert_response :success
  end
end
