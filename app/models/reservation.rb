class Reservation < ApplicationRecord
  belongs_to :user

  validates :start_time, presence: { message: "を入力してください" }
  validates :end_time, presence: { message: "を入力してください" }
  validate :start_at_cannot_be_in_the_past
  validate :end_at_must_be_after_start_at
  validate :cannot_overlap_with_others
  validates :purpose, length: { maximum: 15 }

  attr_accessor :reservation_date, :start_time, :end_time

  before_validation :combine_date_and_time

  private

  def combine_date_and_time
    # Use provided reservation_date, or fall back to existing start_at date if available
    date_val = reservation_date.presence || start_at&.to_date

    return unless date_val.present? && start_time.present? && end_time.present?

    begin
      date = date_val.is_a?(Date) ? date_val : Date.parse(date_val.to_s)
    rescue ArgumentError
      errors.add(:reservation_date, "日付形式が正しくありません")
      return
    end

    begin
      s_time = Time.parse(start_time.to_s)
    rescue ArgumentError
      errors.add(:start_time, "形式が正しくありません")
      return
    end

    begin
      e_time = Time.parse(end_time.to_s)
    rescue ArgumentError
      errors.add(:end_time, "形式が正しくありません")
      return
    end

    self.start_at = date.in_time_zone.change(hour: s_time.hour, min: s_time.min)
    self.end_at = date.in_time_zone.change(hour: e_time.hour, min: e_time.min)
  end


  def end_at_must_be_after_start_at
    return if start_at.blank? || end_at.blank?

    if end_at <= start_at
      errors.add(:end_time, "開始時刻より先の時刻を指定してください")
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
      errors.add(:base, "指定された時間は既に予約が入っています")
    end
  end

  def start_at_cannot_be_in_the_past
    return if start_at.blank?

    if start_at < Time.current
      errors.add(:start_time, "現在時刻より先の時刻を指定してください")
    end
  end
end
