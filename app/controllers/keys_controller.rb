class KeysController < ApplicationController
  before_action :authenticate_user!, only: [ :index, :transfer_form, :transfer, :assign_form, :assign, :unassign ]
  before_action :set_room, only: [ :transfer_form, :transfer, :assign_form, :assign, :unassign ]
  before_action :require_admin!, only: [ :assign_form, :assign, :unassign ]

  # GET /keys
  # 鍵管理画面：全ての部室と現在の鍵持ちを表示
  def index
    @rooms = Room.includes(keys: :user).order(room_number: :desc)
    @users = User.where.not(id: current_user.id).order(:display_name)
  end

  # GET /rooms/:room_id/key/transfer_form
  def transfer_form
    return if performed?

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
    return if performed?

    from_user = resolve_from_user
    return if performed?

    unless transfer_params[:to_user_id].present?
      redirect_back fallback_location: keys_path, alert: "譲渡先を選択してください"
      return
    end

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

  # GET /rooms/:room_id/key/assign_form
  # 管理者が未割り当ての鍵を割り当てるフォーム
  def assign_form
    return if performed?

    unless @room.keys.any? { |k| k.user_id.nil? }
      redirect_to keys_path, alert: "この部屋には未割り当ての鍵がありません"
      return
    end

    existing_holder_ids = @room.keys.select(&:user_id).map(&:user_id)
    @eligible_users = User.where.not(id: existing_holder_ids).order(:display_name)
  end

  # POST /rooms/:room_id/key/assign
  # 管理者が未割り当ての鍵をユーザーに割り当てる
  def assign
    return if performed?

    unless assign_params[:to_user_id].present?
      redirect_back fallback_location: keys_path, alert: "割り当て先を選択してください"
      return
    end

    KeyService.assign(
      room_id: @room.id,
      to_user_id: assign_params[:to_user_id]
    )

    redirect_to keys_path, notice: "鍵を割り当てました"
  rescue ActiveRecord::RecordNotFound
    redirect_to keys_path, alert: "指定された部屋またはユーザーが見つかりません"
  rescue KeyService::TransferError => e
    redirect_to keys_path, alert: e.message
  end

  # POST /rooms/:room_id/key/unassign
  # 管理者が鍵の割り当てを解除する
  def unassign
    return if performed?

    unless unassign_params[:user_id].present?
      redirect_to keys_path, alert: "対象ユーザーが指定されていません"
      return
    end

    KeyService.unassign(
      room_id: @room.id,
      user_id: unassign_params[:user_id]
    )

    redirect_to keys_path, notice: "鍵の割り当てを解除しました"
  rescue ActiveRecord::RecordNotFound
    redirect_to keys_path, alert: "指定されたユーザーはこの部屋の鍵を保持していません"
  end

  private

  def set_room
    @room = Room.includes(keys: :user).find(params[:room_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to keys_path, alert: "指定された部屋が見つかりません"
    @room = nil
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

  def require_admin!
    unless current_user.admin?
      redirect_to keys_path, alert: "権限がありません"
    end
  end

  def transfer_params
    params.permit(:to_user_id, :from_user_id)
  end

  def assign_params
    params.permit(:to_user_id)
  end

  def unassign_params
    params.permit(:user_id)
  end
end
