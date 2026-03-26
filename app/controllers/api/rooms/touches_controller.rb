# frozen_string_literal: true

module Api
  module Rooms
    # NFC Raspi専用: カードタッチによる入退室・カード登録
    class TouchesController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_api_key!

      # POST /api/rooms/:room_id/touch
      def create
        room = Room.find(params[:room_id])
        card_data = params.permit(:student_id, :student_name).to_h.symbolize_keys
        result = NfcTouchService.process(room: room, card_uid: params[:card_uid], card_data: card_data)

        render json: result, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "部室が見つかりません" }, status: :not_found
      rescue NfcTouchService::TouchError => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue RoomEntryService::EntryError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
