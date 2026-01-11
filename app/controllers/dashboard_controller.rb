class DashboardController < ApplicationController
  def index
    @reservations = Reservation.where(start_at: Time.zone.now.all_day).includes(:user).order(:start_at)
    @keys = Key.includes(:user, :room).all.order("rooms.room_number ASC")
  end
end
