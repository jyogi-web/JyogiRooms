class DashboardController < ApplicationController
  def index
    @reservations = Reservation.where(start_at: Time.zone.now.all_day).includes(:user).order(:start_at)
    @rooms = Room.includes(keys: :user).order(room_number: :desc)

    room_ids = @rooms.map(&:id)
    open_room_ids = RoomSession.active.where(room_id: room_ids).pluck(:room_id).to_set
    visit_counts = RoomVisit.active.where(room_id: room_ids).group(:room_id).count
    visits_by_room = RoomVisit.active.where(room_id: room_ids).includes(:user).group_by(&:room_id)

    @room_statuses = @rooms.map do |room|
      {
        room: room,
        is_open: open_room_ids.include?(room.id),
        occupant_count: visit_counts[room.id].to_i,
        occupants: (visits_by_room[room.id] || []).first(5).map(&:user)
      }
    end
  end
end
