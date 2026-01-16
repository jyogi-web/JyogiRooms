class KeysController < ApplicationController
  before_action :authenticate_user!, only: [ :index, :transfer ]

  # GET /keys
  # 鍵管理画面：全ての部室と現在の鍵持ちを表示
  def index
    @rooms = Room.includes(keys: :user).order(:room_number)
    @users = User.order(:display_name)
  end

  # POST /rooms/:room_id/key/transfer
  # 鍵を譲渡する
  def transfer
    KeyService.transfer(
      room_id: params[:room_id],
      from_user: current_user,
      to_user_id: transfer_params[:to_user_id]
    )

    redirect_to keys_path, notice: "鍵を譲渡しました"
  rescue ActiveRecord::RecordNotFound
    redirect_to keys_path, alert: "指定された部屋または譲渡先ユーザーが見つかりません"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to keys_path, alert: "鍵の譲渡に失敗しました：#{e.message}"
  end

  private

  def transfer_params
    params.permit(:to_user_id)
  end
end
