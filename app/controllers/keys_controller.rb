class KeysController < ApplicationController
  before_action :authenticate_user!, only: [ :update ]

  # GET /rooms/:room_id/key
  # 現在の鍵持ちを取得
  def show
    users = Key.current_holder_by_room_id(params[:room_id])

    render json: {
      room_id: params[:room_id],
      users: users.map { |user|
        {
          id: user.id,
          display_name: user.display_name
        }
      }
    }
  end

  # PATCH /rooms/:room_id/key
  # 鍵を譲渡する
  def update
    KeyService.transfer(
      room_id: params[:room_id],
      from_user: current_user,
      to_user_id: params[:to_user_id]
    )

    render json: { status: "ok" }
  end
end
