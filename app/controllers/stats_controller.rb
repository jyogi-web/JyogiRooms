# frozen_string_literal: true

class StatsController < ApplicationController
  include PeriodFilterable

  before_action :require_stats_enabled, only: %i[ranking me]

  # GET /stats/ranking
  def ranking
    @period = valid_period(params[:period])
    @type = params[:type].presence || "visits"
    @room_param = params[:room].presence || "all"

    @rooms = Room.order(:id)

    base_scope = RoomVisit.all
    date_range = period_date_range(@period)
    base_scope = base_scope.where(entered_at: date_range) if date_range
    unless @room_param == "all"
      parsed_room = @rooms.find { |r| r.id.to_s == @room_param }
      base_scope = base_scope.where(room_id: parsed_room.id) if parsed_room
    end

    @ranking = if @type == "duration"
      duration_ranking(base_scope)
    else
      visit_ranking(base_scope)
    end
  end

  # GET /stats/me
  def me
    @period = valid_period(params[:period])

    base_scope = RoomVisit.where(user: current_user)
    date_range = period_date_range(@period)
    base_scope = base_scope.where(entered_at: date_range) if date_range

    @total_visit_days = base_scope
      .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
    @total_duration = base_scope
      .sum("EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))").to_i

    @rooms = Room.order(:id)

    visit_by_room = base_scope
      .group(:room_id)
      .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")

    duration_by_room = base_scope
      .group(:room_id)
      .sum("EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))")

    @per_room = @rooms.map do |room|
      {
        room: room,
        visit_days: visit_by_room[room.id] || 0,
        total_seconds: (duration_by_room[room.id] || 0).to_i
      }
    end

    @heatmap_data = build_heatmap_data(base_scope, @period)
  end

  private

  # 統計・ランキングが無効な場合は「工事中」ページを表示して処理を打ち切る
  def require_stats_enabled
    return if Setting.stats_enabled?

    render "stats/disabled"
  end

  def heatmap_start_date(period)
    end_date = Date.current
    case period
    when "week"
      6.days.ago(end_date)
    when "month"
      1.month.ago(end_date)
    when "half_year"
      26.weeks.ago(end_date).beginning_of_week(:sunday)
    when "year"
      52.weeks.ago(end_date).beginning_of_week(:sunday)
    when "all"
      52.weeks.ago(end_date).beginning_of_week(:sunday)
    else
      52.weeks.ago(end_date).beginning_of_week(:sunday)
    end
  end

  def valid_period(param)
    value = param.presence
    VALID_PERIODS.include?(value) ? value : "all"
  end

  def visit_ranking(scope)
    results = scope
      .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
      .group(:user_id)
      .order("visit_count DESC")

    users = User.where(id: results.map(&:user_id)).index_by(&:id)
    entries = results.map { |r| { user: users[r.user_id], count: r.visit_count.to_i } }
    assign_ranks(entries) { |e| e[:count] }
  end

  def duration_ranking(scope)
    results = scope
      .select("user_id, SUM(EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))) AS total_seconds")
      .group(:user_id)
      .order("total_seconds DESC")

    users = User.where(id: results.map(&:user_id)).index_by(&:id)
    entries = results.map { |r| { user: users[r.user_id], total_seconds: r.total_seconds.to_i } }
    assign_ranks(entries) { |e| e[:total_seconds] }
  end

  def assign_ranks(entries)
    rank = 0
    prev_value = nil
    entries.each_with_index do |entry, i|
      value = yield(entry)
      rank = i + 1 if value != prev_value
      entry[:rank] = rank
      prev_value = value
    end
    entries
  end

  def build_heatmap_data(scope, period)
    end_date = Date.current
    start_date = heatmap_start_date(period)

    # カレンダーの表示範囲（週の区切りに合わせる）
    display_start_date = start_date.beginning_of_week(:sunday)
    display_end_date = end_date.end_of_week(:sunday)

    daily_duration = scope
      .group("DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
      .sum("EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))")

    duration_by_date = daily_duration.transform_keys { |k| k.is_a?(Date) ? k : Date.parse(k) }

    daily_room_duration = scope
      .group("DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')", :room_id)
      .sum("EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))")

    rooms_by_id = Room.order(:id).index_by(&:id)

    room_duration_by_date = {}
    daily_room_duration.each do |(date_str, room_id), seconds|
      date = date_str.is_a?(Date) ? date_str : Date.parse(date_str)
      room = rooms_by_id[room_id]
      next unless room
      room_duration_by_date[date] ||= []
      room_duration_by_date[date] << { room_name: room.name, seconds: seconds.to_i }
    end

    max_duration = duration_by_date.values.max || 1

    days = (display_start_date..display_end_date).map do |date|
      in_period = date >= start_date && date <= end_date
      seconds = in_period ? (duration_by_date[date] || 0).to_i : 0
      level = if !in_period || seconds == 0
        0
      else
        [ (seconds.to_f / max_duration * 4).ceil, 4 ].min
      end
      room_durations = in_period ? (room_duration_by_date[date] || []) : []
      { date: date, seconds: seconds, level: level, room_durations: room_durations, in_period: in_period }
    end

    { days: days, start_date: display_start_date, end_date: display_end_date }
  end
end
