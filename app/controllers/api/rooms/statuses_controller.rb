# frozen_string_literal: true

module Api
  module Rooms
    # 部室状況API
    class StatusesController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_api_key!

      # GET /api/rooms/:room_id/status
      def show
        room = Room.includes(:room_status).find(params[:room_id])
        status = room.room_status

        render json: {
          room: { id: room.id, name: room.name },
          is_open: status.is_open,
          opened_at: status.opened_at&.iso8601,
          opened_by: status.opened_by_id ? { id: status.opened_by_id, display_name: status.opened_by.display_name } : nil,
          occupants: status.occupants.map { |o| { id: o["user_id"], display_name: o["display_name"], entered_at: o["entered_at"] } },
          occupant_count: status.occupant_count
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "部室が見つかりません" }, status: :not_found
      end
    end
  end
end
