# frozen_string_literal: true

class StatsController < ApplicationController
  # GET /stats/ranking
  def ranking
    @period = params[:period].presence || "month"
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
    @period = params[:period].presence || "month"

    base_scope = RoomVisit.where(user: current_user)
    date_range = period_date_range(@period)
    base_scope = base_scope.where(entered_at: date_range) if date_range

    @total_visit_days = base_scope
      .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
    @total_duration = base_scope
      .where.not(exited_at: nil)
      .sum("EXTRACT(EPOCH FROM (exited_at - entered_at))").to_i

    @rooms = Room.order(:id)

    visit_by_room = base_scope
      .group(:room_id)
      .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")

    duration_by_room = base_scope
      .where.not(exited_at: nil)
      .group(:room_id)
      .sum("EXTRACT(EPOCH FROM (exited_at - entered_at))")

    @per_room = @rooms.map do |room|
      {
        room: room,
        visit_days: visit_by_room[room.id] || 0,
        total_seconds: (duration_by_room[room.id] || 0).to_i
      }
    end
  end

  private

  def period_date_range(period)
    now = Time.current.in_time_zone("Asia/Tokyo")
    case period
    when "today"
      now.beginning_of_day..now
    when "week"
      now.beginning_of_week(:monday)..now
    when "month"
      now.beginning_of_month..now
    when "half_year"
      6.months.ago.in_time_zone("Asia/Tokyo").beginning_of_day..now
    when "year"
      1.year.ago.in_time_zone("Asia/Tokyo").beginning_of_day..now
    when "all"
      nil
    end
  end

  def visit_ranking(scope)
    results = scope
      .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
      .group(:user_id)
      .order("visit_count DESC")

    users = User.where(id: results.map(&:user_id)).index_by(&:id)
    results.map { |r| { user: users[r.user_id], count: r.visit_count.to_i } }
  end

  def duration_ranking(scope)
    results = scope
      .where.not(exited_at: nil)
      .select("user_id, SUM(EXTRACT(EPOCH FROM (exited_at - entered_at))) AS total_seconds")
      .group(:user_id)
      .order("total_seconds DESC")

    users = User.where(id: results.map(&:user_id)).index_by(&:id)
    results.map { |r| { user: users[r.user_id], total_seconds: r.total_seconds.to_i } }
  end
end
