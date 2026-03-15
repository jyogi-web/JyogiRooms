require "test_helper"

class KeyServiceTest < ActiveSupport::TestCase
  def setup
    @room = Room.create!(
      name: "部室",
      room_number: "101"
    )

    @from_user = User.create!(
      discord_id: "from_user",
      display_name: "譲渡元"
    )

    @to_user = User.create!(
      discord_id: "to_user",
      display_name: "譲渡先"
    )
  end

  # =====================
  # transfer
  # =====================

  test "transfer updates key owner and creates transfer log" do
    key = Key.create!(room: @room, user: @from_user)

    assert_difference "KeyTransferLog.count", 1 do
      KeyService.transfer(
        room_id: @room.id,
        from_user: @from_user,
        to_user_id: @to_user.id
      )
    end

    assert_equal @to_user, key.reload.user

    log = KeyTransferLog.last
    assert_equal @from_user, log.from_user
    assert_equal @to_user, log.to_user
    assert_equal @room, log.room
  end

  # =====================
  # assign
  # =====================

  test "assign assigns unassigned key to user" do
    Key.create!(room: @room, user: nil)

    KeyService.assign(room_id: @room.id, to_user_id: @to_user.id)

    key = Key.find_by(room: @room, user: @to_user)
    assert_not_nil key
  end

  test "assign raises error when no unassigned key exists" do
    Key.create!(room: @room, user: @from_user)

    assert_raises KeyService::TransferError do
      KeyService.assign(room_id: @room.id, to_user_id: @to_user.id)
    end
  end

  test "assign raises error when user already has key for that room" do
    Key.create!(room: @room, user: nil)
    Key.create!(room: @room, user: @to_user)

    assert_raises KeyService::TransferError do
      KeyService.assign(room_id: @room.id, to_user_id: @to_user.id)
    end
  end

  # =====================
  # unassign
  # =====================

  test "unassign removes user from key" do
    key = Key.create!(room: @room, user: @from_user)

    KeyService.unassign(room_id: @room.id, user_id: @from_user.id)

    assert_nil key.reload.user_id
  end

  test "unassign raises error when user does not have key" do
    Key.create!(room: @room, user: nil)

    assert_raises ActiveRecord::RecordNotFound do
      KeyService.unassign(room_id: @room.id, user_id: @from_user.id)
    end
  end

  # =====================
  # transfer (error cases)
  # =====================

  test "transfer raises error when from_user does not own the key" do
    Key.create!(room: @room, user: @to_user)

    assert_raises ActiveRecord::RecordNotFound do
      KeyService.transfer(
        room_id: @room.id,
        from_user: @from_user,
        to_user_id: @to_user.id
      )
    end
  end
end
