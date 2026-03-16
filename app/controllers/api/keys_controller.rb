# frozen_string_literal: true

module Api
  class KeysController < BaseController
    skip_before_action :authenticate_user!
    before_action :authenticate_api_key!

    # GET /api/keys
    def index
      rooms = Room.includes(keys: :user).order(:id)

      render json: rooms.map { |room|
        {
          room_id: room.id,
          room_name: room.name,
          room_number: room.room_number,
          keys: room.keys.order(:id).map { |key|
            {
              id: key.id,
              holder: key.user ? {
                id: key.user.id,
                username: key.user.username,
                display_name: key.user.display_name,
                discord_id: key.user.discord_id
              } : nil
            }
          }
        }
      }
    end
  end
end
