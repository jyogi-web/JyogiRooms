class KeysController < ApplicationController
  before_action :authenticate_user!, only: [ :update, :create ]

  # GET /keys
  # 鍵管理画面：全ての部室と現在の鍵持ちを表示
  def index
    @rooms = Room.includes(keys: :user).order(:room_number)
    @users = User.order(:display_name)
  end

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

  # POST /keys
  # 鍵を譲渡する
  def create
    KeyService.transfer(
      room_id: params[:room_id],
      from_user: current_user,
      to_user_id: params[:to_user_id]
    )

    redirect_to keys_path, notice: "鍵を譲渡しました"
  rescue => e
    redirect_to keys_path, alert: "鍵の譲渡に失敗しました：#{e.message}"
  end
end
