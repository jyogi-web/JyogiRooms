# frozen_string_literal: true

module Api
  class StatsController < BaseController
    skip_before_action :authenticate_user!
    before_action :authenticate_api_key!

    # GET /api/stats/ranking
    def ranking
      type = params[:type].presence || "visits"
      year_param = params[:year].presence || current_fiscal_year.to_s
      room = params[:room].presence || "all"

      unless %w[visits duration].include?(type)
        return render json: { error: "Invalid type. Use 'visits' or 'duration'." }, status: :bad_request
      end

      base_scope = RoomVisit.all
      year = parse_year_param(year_param)
      return render json: { error: "Invalid year." }, status: :bad_request if year.nil?

      if year != "all"
        start_date, end_date = fiscal_year_range(year)
        base_scope = base_scope.where(entered_at: start_date..end_date)
      end
      base_scope = base_scope.where(room_id: room) unless room == "all"

      ranking_data = if type == "visits"
        visit_ranking(base_scope, room)
      else
        duration_ranking(base_scope)
      end

      render json: {
        type: type,
        year: year,
        room: room,
        ranking: ranking_data
      }
    end

    # GET /api/stats/me
    def me
      user = User.find_by(discord_id: params[:discord_user_id])
      return render json: { error: "User not found." }, status: :not_found unless user

      year_param = params[:year].presence || current_fiscal_year.to_s

      base_scope = RoomVisit.where(user: user)
      year = parse_year_param(year_param)
      return render json: { error: "Invalid year." }, status: :bad_request if year.nil?

      if year != "all"
        start_date, end_date = fiscal_year_range(year)
        base_scope = base_scope.where(entered_at: start_date..end_date)
      end

      # 全部室合算
      total_visit_days = base_scope
        .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
      total_duration = base_scope
        .where.not(exited_at: nil)
        .sum("EXTRACT(EPOCH FROM (exited_at - entered_at))").to_i

      # 部室ごと
      rooms = Room.order(:id)
      per_room = rooms.map do |room|
        room_scope = base_scope.where(room: room)
        visit_days = room_scope
          .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
        duration = room_scope
          .where.not(exited_at: nil)
          .sum("EXTRACT(EPOCH FROM (exited_at - entered_at))").to_i

        {
          room_id: room.id,
          room_name: room.name,
          visit_days: visit_days,
          total_seconds: duration
        }
      end

      # デフォルト条件（訪問日数/今年度/全部室）でのランキング順位
      fiscal_year = current_fiscal_year
      rank_start, rank_end = fiscal_year_range(fiscal_year)
      rank_scope = RoomVisit.where(entered_at: rank_start..rank_end)
      all_visit_counts = rank_scope
        .group(:user_id)
        .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
        .order("visit_count DESC, user_id ASC")
      rank_position = all_visit_counts.each_with_index.find { |r, _| r.user_id == user.id }&.last
      visit_rank = rank_position ? rank_position + 1 : nil
      total_ranked_users = all_visit_counts.length

      render json: {
        user: { id: user.id, display_name: user.display_name, discord_id: user.discord_id },
        year: year,
        total: { visit_days: total_visit_days, total_seconds: total_duration },
        rooms: per_room,
        rank: { position: visit_rank, total_users: total_ranked_users, fiscal_year: fiscal_year }
      }
    end

    private

    def parse_year_param(year_param)
      return "all" if year_param == "all"
      return nil unless year_param.match?(/\A\d{4}\z/)

      year_param.to_i
    end

    def current_fiscal_year
      today = Time.current.in_time_zone("Asia/Tokyo").to_date
      today.month >= 4 ? today.year : today.year - 1
    end

    def fiscal_year_range(year)
      start_date = Time.zone.parse("#{year}-04-01").in_time_zone("Asia/Tokyo").beginning_of_day
      end_date = Time.zone.parse("#{year + 1}-03-31").in_time_zone("Asia/Tokyo").end_of_day
      [ start_date, end_date ]
    end

    def visit_ranking(scope, _room)
      # 訪問回数: 1日1カウント（同日複数入室でも1）
      # room=all の場合は部室横断で日付DISTINCT、部室指定時はscopeで既に絞り込み済み
      results = scope
        .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
        .group(:user_id)
        .order("visit_count DESC")
        .limit(10)

      users = User.where(id: results.map(&:user_id)).index_by(&:id)

      results.map do |r|
        user = users[r.user_id]
        {
          user_id: r.user_id,
          display_name: user&.display_name,
          discord_id: user&.discord_id,
          count: r.visit_count.to_i
        }
      end
    end

    def duration_ranking(scope)
      # 滞在時間: exited_at IS NOT NULL のみ集計
      results = scope
        .where.not(exited_at: nil)
        .select("user_id, SUM(EXTRACT(EPOCH FROM (exited_at - entered_at))) AS total_seconds")
        .group(:user_id)
        .order("total_seconds DESC")
        .limit(10)

      users = User.where(id: results.map(&:user_id)).index_by(&:id)

      results.map do |r|
        user = users[r.user_id]
        {
          user_id: r.user_id,
          display_name: user&.display_name,
          discord_id: user&.discord_id,
          total_seconds: r.total_seconds.to_i
        }
      end
    end
  end
end
