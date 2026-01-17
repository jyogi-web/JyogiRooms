class DashboardController < ApplicationController
  def index
    @reservations = Reservation.where(start_at: Time.zone.now.all_day).includes(:user).order(:start_at)
    @rooms = Room.includes(keys: :user).order(room_number: :desc)
  end
end
