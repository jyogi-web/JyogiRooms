class Reservation < ApplicationRecord
  belongs_to :user

  validates :start_at, presence: true
  validates :end_at, presence: true
  validate :end_at_must_be_after_start_at
  validate :cannot_overlap_with_others

  private

  def end_at_must_be_after_start_at
    return if start_at.blank? || end_at.blank?

    if end_at <= start_at
      errors.add(:end_at, 'must be after the start time')
    end
  end

  def cannot_overlap_with_others
    return if start_at.blank? || end_at.blank?

    # Check for overlapping reservations:
    # (StartA < EndB) AND (EndA > StartB)
    existing_reservation = Reservation
                           .where.not(id: id)
                           .where('start_at < ? AND end_at > ?', end_at, start_at)
                           .exists?

    if existing_reservation
      errors.add(:base, 'This time slot is already booked')
    end
  end
end
