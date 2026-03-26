class DashboardController < ApplicationController
  def index
    @reservations = Reservation.where(start_at: Time.zone.now.all_day).includes(:user).order(:start_at)
    @rooms = Room.includes(keys: :user).order(room_number: :desc)
    @room_statuses = @rooms.map do |room|
      active_visits = RoomVisit.active.for_room(room).includes(:user).limit(5)
      {
        room: room,
        is_open: RoomSession.active.for_room(room).exists?,
        occupant_count: RoomVisit.active.for_room(room).count,
        occupants: active_visits.map(&:user)
      }
    end
  end
end
