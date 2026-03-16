require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  def setup
    AccessToken.delete_all
    Reservation.delete_all
    User.delete_all
    @user = User.create!
    @reservation = Reservation.create!(
      user: @user,
      start_at: 1.day.from_now.change(hour: 10, min: 0),
      end_at: 1.day.from_now.change(hour: 12, min: 0)
    )
  end

  test "should be valid" do
    assert @reservation.valid?
  end

  test "should require user" do
    @reservation.user = nil
    assert_not @reservation.valid?
  end

  test "should require start_at" do
    @reservation.start_at = nil
    assert_not @reservation.valid?
  end

  test "should require end_at" do
    @reservation.end_at = nil
    assert_not @reservation.valid?
  end

  test "end_at should be after start_at" do
    @reservation.end_at = @reservation.start_at - 1.hour
    assert_not @reservation.valid?
    # Ensure checking the correct attribute and message
    assert_includes @reservation.errors[:end_time], "開始時刻より先の時刻を指定してください"
  end

  test "should not overlap with existing reservation" do
    # Completely inside existing
    new_reservation = Reservation.new(
      user: @user,
      start_at: @reservation.start_at + 10.minutes,
      end_at: @reservation.end_at - 10.minutes
    )
    # Ensure virtual attributes are set for validation
    new_reservation.reservation_date = new_reservation.start_at.to_date
    new_reservation.start_time = new_reservation.start_at.strftime("%H:%M")
    new_reservation.end_time = new_reservation.end_at.strftime("%H:%M")

    assert_not new_reservation.valid?
    assert new_reservation.errors[:base].any? { |msg| msg.include?("指定された時間は既に予約が入っています") }

    # Overlaps start
    new_reservation.start_at = @reservation.start_at - 1.hour
    new_reservation.end_at = @reservation.start_at + 1.hour
    # Update virtuals
    new_reservation.start_time = new_reservation.start_at.strftime("%H:%M")
    new_reservation.end_time = new_reservation.end_at.strftime("%H:%M")

    assert_not new_reservation.valid?

    # Overlaps end
    new_reservation.start_at = @reservation.end_at - 1.hour
    new_reservation.end_at = @reservation.end_at + 1.hour
    # Update virtuals
    new_reservation.start_time = new_reservation.start_at.strftime("%H:%M")
    new_reservation.end_time = new_reservation.end_at.strftime("%H:%M")

    assert_not new_reservation.valid?
  end

  test "should allow non-overlapping reservation" do
    # Just after
    new_reservation = Reservation.new(
      user: @user,
      start_at: @reservation.end_at + 1.minute,
      end_at: @reservation.end_at + 1.hour
    )
    assert new_reservation.valid?
  end
end
