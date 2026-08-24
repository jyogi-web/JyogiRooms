# frozen_string_literal: true

class RoomStatusesController < ApplicationController
  before_action :set_room, only: %i[exit_room close_room force_exit_user]
  before_action :require_force_exit_permission!, only: %i[force_exit_user]

  # GET /room_statuses
  def index
    # 部室状況の閲覧ログ（非同期・ベストエフォート。表示処理はブロックしない）
    RoomViewLogger.log_web_view(current_user)

    @rooms = Room.includes(:room_status, keys: :user).order(room_number: :desc)

    all_statuses = @rooms.map(&:room_status).compact
    occupant_user_ids = all_statuses.flat_map { |s| s.normalized_occupants.map { |o| o["user_id"] } }.uniq
    opener_user_ids = all_statuses.filter_map(&:opened_by_id).uniq
    users_by_id = User.where(id: occupant_user_ids + opener_user_ids).index_by(&:id)

    @room_data = @rooms.map do |room|
      status = room.room_status
      occupants = status.normalized_occupants.filter_map do |o|
        user = users_by_id[o["user_id"]]
        next unless user
        { user: user, entered_at: Time.zone.parse(o["entered_at"]) }
      end

      {
        room: room,
        is_open: status.is_open,
        opened_by: status.opened_by_id ? users_by_id[status.opened_by_id] : nil,
        opened_at: status.opened_at,
        occupants: occupants,
        can_close: can_close?(room),
        is_current_user_inside: occupants.any? { |o| o[:user]&.id == current_user.id }
      }
    end
  end

  # GET /room_statuses/logs
  def logs
    @rooms = Room.order(room_number: :desc)
    @room_param = params[:room] || "all"
    @date_param = parse_logs_date(params[:date])
    @user_id_param = params[:user_id]

    visits = RoomVisit.includes(:user, :room).order(entered_at: :desc)

    visits = visits.where(room_id: @room_param) if @room_param != "all"
    visits = visits.where(user_id: @user_id_param) if @user_id_param.present?

    day_range = @date_param.in_time_zone("Asia/Tokyo").all_day
    visits = visits.where(entered_at: day_range).or(visits.where(exited_at: day_range))

    @visits = visits

    # 入室・退室を個別のログエントリに分解し、時刻降順でソート
    @logs = @visits.flat_map { |visit|
      entries = []
      if day_range.cover?(visit.entered_at.in_time_zone("Asia/Tokyo"))
        entries << { type: :enter, user: visit.user, room: visit.room, at: visit.entered_at, source: nil }
      end
      if visit.exited_at && day_range.cover?(visit.exited_at.in_time_zone("Asia/Tokyo"))
        entries << { type: :exit, user: visit.user, room: visit.room, at: visit.exited_at, source: visit.source }
      end
      entries
    }.sort_by { |e| e[:at] }.reverse

    @users = User.order(:display_name)
  end

  # POST /room_statuses/:id/exit_room
  def exit_room
    RoomEntryService.exit(room: @room, user: current_user, source: "web", exited_by: current_user)
    redirect_to room_statuses_path, notice: "#{@room.name}から退室しました"
  rescue RoomEntryService::EntryError => e
    redirect_to room_statuses_path, alert: e.message
  end

  # POST /room_statuses/:id/close_room
  def close_room
    unless can_close?(@room)
      return redirect_to room_statuses_path, alert: "この部室を閉室する権限がありません"
    end

    RoomStateService.close(room: @room, user: current_user)
    redirect_to room_statuses_path, notice: "#{@room.name}を閉室しました"
  rescue RoomStateService::StateError => e
    redirect_to room_statuses_path, alert: e.message
  end

  # POST /room_statuses/:id/force_exit_user
  def force_exit_user
    user = User.find_by(id: params[:user_id])
    return redirect_to(room_statuses_path, alert: "ユーザーが見つかりません") unless user

    RoomEntryService.exit(
      room: @room,
      user: user,
      source: "forced",
      exited_by: current_user,
      notification_type: "room_exited"
    )
    redirect_to room_statuses_path, notice: "#{user.display_name}を#{@room.name}から退室させました"
  rescue RoomEntryService::EntryError => e
    redirect_to room_statuses_path, alert: e.message
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def can_close?(room)
    return true if effective_admin_or_manager?

    current_user.keys.any? { |key| key.room_id == room.id }
  end

  def require_admin_or_manager!
    return if effective_admin_or_manager?

    redirect_to room_statuses_path, alert: "開発者または管理者のみ実行できます"
  end

  def require_force_exit_permission!
    return if effective_admin_or_manager? || current_user&.observer?

    redirect_to room_statuses_path, alert: "代理退室の権限がありません"
  end

  def parse_logs_date(date_param)
    return Time.zone.today if date_param.blank?

    Date.iso8601(date_param)
  rescue ArgumentError
    Time.zone.today
  end
end
