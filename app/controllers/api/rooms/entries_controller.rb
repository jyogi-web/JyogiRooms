# frozen_string_literal: true

module Api
  module Rooms
    # 入退室API
    class EntriesController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_api_key!
      before_action :set_room, only: %i[enter exit]
      before_action :set_user

      # POST /api/rooms/:room_id/enter (Discord Bot専用)
      def enter
        visit = RoomEntryService.enter(room: @room, user: @user, source: request_source)

        render json: entry_json("enter", visit, @user, @room), status: :ok
      rescue RoomEntryService::EntryError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/rooms/:room_id/exit
      def exit
        visit = RoomEntryService.exit(room: @room, user: @user)

        render json: entry_json("exit", visit, @user, @room), status: :ok
      rescue RoomEntryService::EntryError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/exit（部室指定不要・現在入室中の部室から退室）
      def exit_current
        current_visit = RoomVisit.active.for_user(@user).first
        unless current_visit
          return render json: { error: "現在入室中の部室がありません" }, status: :unprocessable_entity
        end

        room = current_visit.room
        visit = RoomEntryService.exit(room: room, user: @user)

        render json: entry_json("exit", visit, @user, room), status: :ok
      rescue RoomEntryService::EntryError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      ALLOWED_SOURCES = %w[nfc web discord].freeze

      def set_room
        @room = Room.find(params[:room_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "部室が見つかりません" }, status: :not_found
      end

      def set_user
        @user = if params[:user_id].present?
                  User.find_by(id: params[:user_id])
                elsif params[:discord_user_id].present?
                  User.find_by(discord_id: params[:discord_user_id])
                end

        render(json: { error: "ユーザーが見つかりません" }, status: :not_found) unless @user
      end

      def request_source
        source = params[:source].presence
        ALLOWED_SOURCES.include?(source) ? source : "discord"
      end

      def entry_json(action, visit, user, room)
        timestamp = action == "exit" ? visit.exited_at : visit.entered_at
        {
          action: action,
          user: { id: user.id, display_name: user.display_name },
          room: { id: room.id, name: room.name },
          timestamp: timestamp.iso8601
        }
      end
    end
  end
end
