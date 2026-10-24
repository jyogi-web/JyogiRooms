# frozen_string_literal: true

module Api
  module Rooms
    # 開閉室API
    class StatesController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_api_key!
      before_action :set_room
      before_action :set_user
      before_action :authorize_key_holder!

      # POST /api/rooms/:room_id/open (Discord Bot専用)
      def open
        session = RoomStateService.open(room: @room, user: @user)

        render json: state_json("open", session, @user), status: :ok
      rescue RoomStateService::StateError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/rooms/:room_id/close
      def close
        session = RoomStateService.close(room: @room, user: @user)

        render json: state_json("close", session, @user), status: :ok
      rescue RoomStateService::StateError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

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

      def authorize_key_holder!
        return if @user&.admin_or_manager?
        return if Key.exists?(room: @room, user: @user)

        render json: { error: "この部室の鍵持ちまたは開発者/管理者のみ実行できます" }, status: :forbidden
      end

      def state_json(action, session, user)
        {
          action: action,
          user: { id: user.id, display_name: user.display_name },
          room: { id: @room.id, name: @room.name },
          timestamp: (action == "open" ? session.opened_at : session.closed_at).iso8601
        }
      end
    end
  end
end
