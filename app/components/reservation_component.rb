class ReservationComponent < ViewComponent::Base
  def initialize(reservation:, layout: :dashboard)
    @reservation = reservation
    @layout = layout
  end

  def render?
    @reservation.present?
  end

  private

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
    helpers.current_user == @reservation.user
  end
end
