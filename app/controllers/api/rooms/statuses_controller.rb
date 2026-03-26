# frozen_string_literal: true

module Api
  module Rooms
    # 部室状況API
    class StatusesController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_api_key!

      # GET /api/rooms/:room_id/status
      def show
        room = Room.find(params[:room_id])
        session = RoomSession.active.for_room(room).first
        occupants = RoomVisit.active.for_room(room).includes(:user).map do |visit|
          {
            id: visit.user.id,
            display_name: visit.user.display_name,
            entered_at: visit.entered_at.iso8601
          }
        end

        render json: {
          room: { id: room.id, name: room.name },
          is_open: session.present?,
          opened_at: session&.opened_at&.iso8601,
          opened_by: session ? { id: session.opened_by.id, display_name: session.opened_by.display_name } : nil,
          occupants: occupants,
          occupant_count: occupants.size
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "部室が見つかりません" }, status: :not_found
      end
    end
  end
end
