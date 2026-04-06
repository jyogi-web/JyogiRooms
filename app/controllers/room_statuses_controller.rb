# frozen_string_literal: true

class RoomStatusesController < ApplicationController
  include PeriodFilterable

  before_action :set_room, only: %i[exit_room close_room]

  # GET /room_statuses
  def index
    @rooms = Room.includes(:room_status, keys: :user).order(room_number: :desc)

    all_statuses = @rooms.map(&:room_status).compact
    occupant_user_ids = all_statuses.flat_map { |s| s.occupants.map { |o| o["user_id"] } }.uniq
    opener_user_ids = all_statuses.filter_map(&:opened_by_id).uniq
    users_by_id = User.where(id: occupant_user_ids + opener_user_ids).index_by(&:id)

    @room_data = @rooms.map do |room|
      status = room.room_status
      occupants = status.occupants.filter_map do |o|
        user = users_by_id[o["user_id"]]
        next unless user
        { user: user, entered_at: Time.zone.parse(o["entered_at"]) }
      end

      {
        room: room,
        is_open: status.is_open,
        opened_by: status.opened_by_id ? users_by_id[status.opened_by_id] : nil,
        opened_at: status.opened_at,
        occupants: occupants,
        can_close: can_close?(room),
        is_current_user_inside: occupants.any? { |o| o[:user]&.id == current_user.id }
      }
    end
  end

  # GET /room_statuses/logs
  def logs
    @rooms = Room.order(room_number: :desc)
    @room_param = params[:room] || "all"
    @period = PeriodFilterable::VALID_PERIODS.include?(params[:period]) ? params[:period] : "all"
    @user_id_param = params[:user_id]

    visits = RoomVisit.includes(:user, :room).where.not(exited_at: nil).order(entered_at: :desc)

    visits = visits.where(room_id: @room_param) if @room_param != "all"
    visits = visits.where(user_id: @user_id_param) if @user_id_param.present?

    range = period_date_range(@period)
    visits = visits.where(entered_at: range) if range

    @visits = visits.limit(100)
    @users = User.order(:display_name)
  end

  # POST /room_statuses/:id/exit_room
  def exit_room
    RoomEntryService.exit(room: @room, user: current_user)
    redirect_to room_statuses_path, notice: "#{@room.name}から退室しました"
  rescue RoomEntryService::EntryError => e
    redirect_to room_statuses_path, alert: e.message
  end

  # POST /room_statuses/:id/close_room
  def close_room
    unless can_close?(@room)
      return redirect_to room_statuses_path, alert: "この部室を閉室する権限がありません"
    end

    RoomStateService.close(room: @room, user: current_user)
    redirect_to room_statuses_path, notice: "#{@room.name}を閉室しました"
  rescue RoomStateService::StateError => e
    redirect_to room_statuses_path, alert: e.message
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def can_close?(room)
    return true if effective_admin?

    current_user.keys.any? { |key| key.room_id == room.id }
  end
end
