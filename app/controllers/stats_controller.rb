# frozen_string_literal: true

class StatsController < ApplicationController
  # GET /stats/ranking
  def ranking
    @year_param = params[:year].presence || current_fiscal_year.to_s
    @type = params[:type].presence || "visits"
    @room_param = params[:room].presence || "all"

    @year = parse_year_param(@year_param)
    @rooms = Room.order(:id)

    base_scope = RoomVisit.all
    if @year != "all"
      start_date, end_date = fiscal_year_range(@year)
      base_scope = base_scope.where(entered_at: start_date..end_date)
    end
    base_scope = base_scope.where(room_id: @room_param) unless @room_param == "all"

    @ranking = if @type == "duration"
      duration_ranking(base_scope)
    else
      visit_ranking(base_scope)
    end
  end

  # GET /stats/me
  def me
    @year_param = params[:year].presence || current_fiscal_year.to_s
    @year = parse_year_param(@year_param)

    base_scope = RoomVisit.where(user: current_user)
    if @year != "all"
      start_date, end_date = fiscal_year_range(@year)
      base_scope = base_scope.where(entered_at: start_date..end_date)
    end

    @total_visit_days = base_scope
      .count("DISTINCT DATE(entered_at AT TIME ZONE 'Asia/Tokyo')")
    @total_duration = base_scope
      .where.not(exited_at: nil)
      .sum("EXTRACT(EPOCH FROM (exited_at - entered_at))").to_i

    @rooms = Room.order(:id)
    @per_room = @rooms.map do |room|
      room_scope = base_scope.where(room: room)
      {
        room: room,
        visit_days: room_scope.count("DISTINCT DATE(entered_at AT TIME ZONE 'Asia/Tokyo')"),
        total_seconds: room_scope.where.not(exited_at: nil)
          .sum("EXTRACT(EPOCH FROM (exited_at - entered_at))").to_i
      }
    end
  end

  private

  def current_fiscal_year
    today = Time.current.in_time_zone("Asia/Tokyo").to_date
    today.month >= 4 ? today.year : today.year - 1
  end

  def parse_year_param(year_param)
    return "all" if year_param == "all"
    return current_fiscal_year unless year_param.match?(/\A\d{4}\z/)

    year_param.to_i
  end

  def fiscal_year_range(year)
    start_date = Time.zone.parse("#{year}-04-01").in_time_zone("Asia/Tokyo").beginning_of_day
    end_date = Time.zone.parse("#{year + 1}-03-31").in_time_zone("Asia/Tokyo").end_of_day
    [ start_date, end_date ]
  end

  def visit_ranking(scope)
    results = scope
      .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
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
