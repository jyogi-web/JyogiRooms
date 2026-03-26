# frozen_string_literal: true

class RoomStatusesController < ApplicationController
  before_action :set_room, only: %i[exit_room close_room]

  # GET /room_statuses
  def index
    @rooms = Room.includes(keys: :user).order(room_number: :desc)
    @room_data = @rooms.map do |room|
      session = RoomSession.active.for_room(room).first
      occupants = RoomVisit.active.for_room(room).includes(:user).map do |visit|
        { user: visit.user, entered_at: visit.entered_at }
      end

      {
        room: room,
        is_open: session.present?,
        session: session,
        occupants: occupants,
        can_close: can_close?(room),
        is_current_user_inside: occupants.any? { |o| o[:user].id == current_user.id }
      }
    end
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
    return true if current_user.admin?

    current_user.keys.any? { |key| key.room_id == room.id }
  end
end
