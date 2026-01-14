class KeysController < ApplicationController
  # current_user は利用可能前提

  # GET /rooms/:room_id/key
  # 現在の鍵持ちを取得
  def show
     user = KeyService.current_holder(params[:room_id])

    render json: {
      room_id: params[:room_id],
      user_id: user&.id,
      user_name: user&.display_name
    }
  end

  # PATCH /rooms/:room_id/key
  # 鍵を譲渡する
  def update
    KeyService.new(
      room_id: params[:room_id],
      to_user_id: params[:to_user_id],
      current_user: current_user
    ).call

    render json: { status: "ok" }
  end
end
