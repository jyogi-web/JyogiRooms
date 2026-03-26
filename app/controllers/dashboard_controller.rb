class DashboardController < ApplicationController
  def index
    @reservations = Reservation.where(start_at: Time.zone.now.all_day).includes(:user).order(:start_at)
    @rooms = Room.includes(keys: :user).order(room_number: :desc)
    @room_statuses = @rooms.map do |room|
      {
        room: room,
        is_open: RoomSession.active.for_room(room).exists?,
        occupant_count: RoomVisit.active.for_room(room).count
      }
    end
  end
end
