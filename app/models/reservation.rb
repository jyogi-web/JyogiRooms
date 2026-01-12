class Reservation < ApplicationRecord
  belongs_to :user

  validates :start_at, presence: true
  validates :end_at, presence: true
  validate :end_at_must_be_after_start_at
  validate :cannot_overlap_with_others

  attr_accessor :reservation_date, :start_time, :end_time

  before_validation :combine_date_and_time

  private

  def combine_date_and_time
    if reservation_date.present? && start_time.present? && end_time.present?
      begin
        date = Date.parse(reservation_date)
        s_time = Time.parse(start_time)
        e_time = Time.parse(end_time)

        self.start_at = date.in_time_zone.change(hour: s_time.hour, min: s_time.min)
        self.end_at = date.in_time_zone.change(hour: e_time.hour, min: e_time.min)
      rescue ArgumentError
        # Handle invalid date/time parsing if necessary, or let validation fail
        errors.add(:base, "Invalid date or time format")
      end
    end
  end


  def end_at_must_be_after_start_at
    return if start_at.blank? || end_at.blank?

    if end_at <= start_at
      errors.add(:end_at, "must be after the start time")
    end
  end

  def cannot_overlap_with_others
    return if start_at.blank? || end_at.blank?

    # Check for overlapping reservations:
    # (StartA < EndB) AND (EndA > StartB)
    existing_reservation = Reservation
                           .where.not(id: id)
                           .where("start_at < ? AND end_at > ?", end_at, start_at)
                           .exists?

    if existing_reservation
      errors.add(:base, "This time slot is already booked")
    end
  end
end
