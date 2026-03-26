# frozen_string_literal: true

module Api
  module Rooms
    # 入退室API
    class EntriesController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_api_key!
      before_action :set_room

      # POST /api/rooms/:room_id/enter (Discord Bot専用)
      def enter
        user = find_user!
        visit = RoomEntryService.enter(room: @room, user: user, source: request_source)

        render json: entry_json("enter", visit, user), status: :ok
      rescue RoomEntryService::EntryError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/rooms/:room_id/exit
      def exit
        user = find_user!
        visit = RoomEntryService.exit(room: @room, user: user)

        render json: entry_json("exit", visit, user), status: :ok
      rescue RoomEntryService::EntryError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_room
        @room = Room.find(params[:room_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "部室が見つかりません" }, status: :not_found
      end

      def find_user!
        user = if params[:user_id].present?
                 User.find_by(id: params[:user_id])
               elsif params[:discord_user_id].present?
                 User.find_by(discord_id: params[:discord_user_id])
               end

        render(json: { error: "ユーザーが見つかりません" }, status: :not_found) && return unless user
        user
      end

      def request_source
        params[:source].presence || "discord"
      end

      def entry_json(action, visit, user)
        {
          action: action,
          user: { id: user.id, display_name: user.display_name },
          room: { id: @room.id, name: @room.name },
          timestamp: visit.entered_at.iso8601
        }
      end
    end
  end
end
