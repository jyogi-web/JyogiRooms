class KeysController < ApplicationController
  before_action :authenticate_user!, only: [ :index, :transfer_form, :transfer ]
  before_action :set_room, only: [ :transfer_form, :transfer ]

  # GET /keys
  # 鍵管理画面：全ての部室と現在の鍵持ちを表示
  def index
    @rooms = Room.includes(keys: :user).order(room_number: :desc)
    @users = User.where.not(id: current_user.id).order(:display_name)
  end

  # GET /rooms/:room_id/key/transfer_form
  def transfer_form
    @from_user = resolve_from_user
    return if performed?

    unless @room.keys.any? { |k| k.user_id == @from_user.id }
      redirect_to keys_path, alert: "指定したユーザーはこの部屋の鍵を保持していません"
      return
    end

    exclusion_ids = @room.keys.map(&:user_id) + [ @from_user.id ]
    @eligible_users = User.where.not(id: exclusion_ids).order(:display_name)
  rescue ActiveRecord::RecordNotFound
    redirect_to keys_path, alert: "指定された部屋またはユーザーが見つかりません"
  end

  # POST /rooms/:room_id/key/transfer
  # 鍵を譲渡する
  def transfer
    from_user = resolve_from_user
    return if performed?

    KeyService.transfer(
      room_id: @room.id,
      from_user: from_user,
      to_user_id: transfer_params[:to_user_id]
    )

    redirect_to keys_path, notice: "鍵を譲渡しました"
  rescue ActiveRecord::RecordNotFound
    redirect_to keys_path, alert: "指定された部屋または譲渡先ユーザーが見つかりません"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to keys_path, alert: "鍵の譲渡に失敗しました：#{e.message}"
  rescue KeyService::TransferError => e
    redirect_to keys_path, alert: e.message
  end

  private

  def set_room
    @room = Room.includes(keys: :user).find(params[:room_id])
  end

  def resolve_from_user
    from_user_id = params[:from_user_id]

    if current_user.admin?
      User.find(from_user_id)
    else
      return current_user if from_user_id.blank? || from_user_id.to_i == current_user.id

      redirect_to keys_path, alert: "権限がありません"
      nil
    end
  end

  def transfer_params
    params.permit(:to_user_id, :from_user_id)
  end
end
