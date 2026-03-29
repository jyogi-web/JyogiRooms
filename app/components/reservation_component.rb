class ReservationComponent < ViewComponent::Base
  def initialize(reservation:, layout: :dashboard)
    @reservation = reservation
    @layout = layout
  end

  def render?
    @reservation.present?
  end

  private

  def date_label
    @reservation.start_at.strftime("%-m/%-d(#{%w[日 月 火 水 木 金 土][@reservation.start_at.wday]})")
  end

  def start_time
    @reservation.start_at.strftime("%H:%M")
  end

  def end_time
    @reservation.end_at.strftime("%H:%M")
  end

  def user_name
    @reservation.user&.display_name || "Unknown"
  end

  def purpose
    @reservation.purpose.presence
  end

  def owned_by_current_user?
    return false unless helpers.current_user.present?
    helpers.current_user.admin? || helpers.current_user == @reservation.user
  end
end
