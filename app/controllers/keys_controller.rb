class KeysController < ApplicationController
  # current_user は利用可能前提

  # GET /rooms/:room_id/key
  # 現在の鍵持ちを取得
  def show
     users = KeyService.current_holders(params[:room_id])

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
    ).call

    render json: { status: "ok" }
  end
end
