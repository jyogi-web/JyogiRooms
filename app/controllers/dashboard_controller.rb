class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    unless user_signed_in?
      render :landing
      return
    end

    @reservations = Reservation.where(start_at: Time.zone.now.all_day).includes(:user).order(:start_at)
    @rooms = Room.includes(keys: :user).order(room_number: :desc)

    @rooms = @rooms.includes(:room_status)
    all_statuses = @rooms.map(&:room_status).compact
    occupant_user_ids = all_statuses.flat_map { |s| s.occupants.first(5).map { |o| o["user_id"] } }.uniq
    users_by_id = User.where(id: occupant_user_ids).index_by(&:id)

    @room_statuses = @rooms.map do |room|
      status = room.room_status
      {
        room: room,
        is_open: status.is_open,
        occupant_count: status.occupant_count,
        occupants: status.occupants.first(5).filter_map { |o| users_by_id[o["user_id"]] }
      }
    end
  end
end
