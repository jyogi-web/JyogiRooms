# frozen_string_literal: true

class StatsController < ApplicationController
  include PeriodFilterable

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
  end

  private

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
end
