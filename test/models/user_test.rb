require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should have many reservations" do
    user = User.create!(id: 999) # manual creation
    assert_respond_to user, :reservations
    assert_instance_of Reservation, user.reservations.build
  end
end
