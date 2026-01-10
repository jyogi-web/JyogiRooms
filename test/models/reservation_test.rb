require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  def setup
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
    assert_includes @reservation.errors[:end_at], "must be after the start time"
  end

  test "should not overlap with existing reservation" do
    # Completely inside existing
    new_reservation = Reservation.new(
      user: @user,
      start_at: @reservation.start_at + 10.minutes,
      end_at: @reservation.end_at - 10.minutes
    )
    assert_not new_reservation.valid?
    assert_includes new_reservation.errors[:base], "This time slot is already booked"

    # Overlaps start
    new_reservation.start_at = @reservation.start_at - 1.hour
    new_reservation.end_at = @reservation.start_at + 1.hour
    assert_not new_reservation.valid?

    # Overlaps end
    new_reservation.start_at = @reservation.end_at - 1.hour
    new_reservation.end_at = @reservation.end_at + 1.hour
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
