require "test_helper"

class KeyTest < ActiveSupport::TestCase
  def setup
    @room = Room.create!(
      name: "部室",
      room_number: "101"
    )

    @user = User.create!(
      discord_id: "user",
      display_name: "鍵持ち"
    )
  end

  test "current_holder_by_room_id returns users array when key exists" do
    Key.create!(room: @room, user: @user)

    holders = Key.current_holder_by_room_id(@room.id)

    assert_equal [ @user ], holders
  end

  test "current_holder_by_room_id returns empty array when key does not exist" do
    holders = Key.current_holder_by_room_id(@room.id)

    assert_equal [], holders
  end
end
