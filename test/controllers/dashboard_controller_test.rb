require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: "test_user",
      display_name: "Test User",
      discord_id: "test_discord_id",
      jyogi_user_id: SecureRandom.uuid
    )
  end

  test "should get index" do
    sign_in_as(@user)
    get root_url
    assert_response :success
  end
end
