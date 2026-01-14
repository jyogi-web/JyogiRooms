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

  test "current_holder returns user when key exists" do
    Key.create!(room: @room, user: @from_user)

    holder = KeyService.current_holder(@room.id)

    assert_equal @from_user, holder
  end

  test "current_holder returns nil when key does not exist" do
    holder = KeyService.current_holder(@room.id)

    assert_nil holder
  end

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

  test "transfer is rolled back when transfer log creation fails" do
    key = Key.create!(room: @room, user: @from_user)

    # KeyTransferLog.create! を失敗させてロールバックを確認
    KeyTransferLog.stub(:create!, ->(*) { raise ActiveRecord::RecordInvalid.new(KeyTransferLog.new) }) do
      assert_raises ActiveRecord::RecordInvalid do
        KeyService.transfer(
          room_id: `@room.id`,
          from_user: `@from_user`,
          to_user_id: `@to_user.id`
        )
     end
  end

    # 鍵の所有者が元に戻っていること（トランザクション確認）
    assert_equal `@from_user`, key.reload.user
    assert_equal 0, KeyTransferLog.count
  end