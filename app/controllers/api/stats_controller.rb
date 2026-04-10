# frozen_string_literal: true

module Api
  class StatsController < BaseController
    skip_before_action :authenticate_user!
    before_action :authenticate_api_key!
    include PeriodFilterable

    # GET /api/stats/ranking
    def ranking
      type = params[:type].presence || "visits"
      period = params[:period].presence || "all"
      room = params[:room].presence || "all"

      unless %w[visits duration].include?(type)
        return render json: { error: "Invalid type. Use 'visits' or 'duration'." }, status: :bad_request
      end
      unless VALID_PERIODS.include?(period)
        return render json: { error: "Invalid period. Use 'today', 'week', 'month', 'half_year', 'year', or 'all'." }, status: :bad_request
      end

      base_scope = RoomVisit.all
      date_range = period_date_range(period)
      base_scope = base_scope.where(entered_at: date_range) if date_range
      base_scope = base_scope.where(room_id: room) unless room == "all"

      ranking_data = if type == "visits"
        visit_ranking(base_scope, room)
      else
        duration_ranking(base_scope)
      end

      render json: {
        type: type,
        period: period,
        room: room,
        ranking: ranking_data
      }
    end

    # GET /api/stats/visit_days?discord_user_id=xxx&period=all
    def visit_days
      user = User.find_by(discord_id: params[:discord_user_id])
      return render json: { error: "User not found." }, status: :not_found unless user

      period = params[:period].presence || "all"
      unless VALID_PERIODS.include?(period)
        return render json: { error: "Invalid period. Use 'today', 'week', 'month', 'half_year', 'year', or 'all'." }, status: :bad_request
      end

      base_scope = RoomVisit.where(user: user)
      date_range = period_date_range(period)
      base_scope = base_scope.where(entered_at: date_range) if date_range

      visit_days = base_scope
        .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")

      render json: {
        discord_id: user.discord_id,
        period: period,
        visit_days: visit_days
      }
    end

    # GET /api/stats/me
    def me
      user = User.find_by(discord_id: params[:discord_user_id])
      return render json: { error: "User not found." }, status: :not_found unless user

      period = params[:period].presence || "all"
      unless VALID_PERIODS.include?(period)
        return render json: { error: "Invalid period. Use 'today', 'week', 'month', 'half_year', 'year', or 'all'." }, status: :bad_request
      end

      base_scope = RoomVisit.where(user: user)
      date_range = period_date_range(period)
      base_scope = base_scope.where(entered_at: date_range) if date_range

      # 全部室合算
      total_visit_days = base_scope
        .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
      total_duration = base_scope
        .sum("EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))").to_i

      # 部室ごと
      rooms = Room.order(:id)
      per_room = rooms.map do |room|
        room_scope = base_scope.where(room: room)
        visit_days = room_scope
          .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
        duration = room_scope
          .sum("EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))").to_i

        {
          room_id: room.id,
          room_name: room.name,
          visit_days: visit_days,
          total_seconds: duration
        }
      end

      # ランキング順位（ユーザーが選択した期間と同じ範囲で算出）
      rank_range = period_date_range(period)
      rank_scope = rank_range ? RoomVisit.where(entered_at: rank_range) : RoomVisit.all
      all_visit_counts = rank_scope
        .group(:user_id)
        .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
        .order("visit_count DESC, user_id ASC")
      total_ranked_users = all_visit_counts.length

      visit_rank = find_user_rank(all_visit_counts, user.id) { |r| r.visit_count.to_i }

      # 滞在時間ランキング順位
      all_durations = rank_scope
        .group(:user_id)
        .select("user_id, SUM(EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))) AS total_seconds")
        .order("total_seconds DESC, user_id ASC")

      duration_rank = find_user_rank(all_durations, user.id) { |r| r.total_seconds.to_i }

      render json: {
        user: { id: user.id, display_name: user.display_name, discord_id: user.discord_id },
        period: period,
        total: { visit_days: total_visit_days, total_seconds: total_duration },
        rooms: per_room,
        rank: {
          visit: { position: visit_rank, total_users: total_ranked_users },
          duration: { position: duration_rank, total_users: all_durations.length },
          period: period
        }
      }
    end

    private

    def visit_ranking(scope, _room)
      # 訪問回数: 1日1カウント（同日複数入室でも1）
      # room=all の場合は部室横断で日付DISTINCT、部室指定時はscopeで既に絞り込み済み
      results = scope
        .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
        .group(:user_id)
        .order("visit_count DESC")
        .limit(10)

      users = User.where(id: results.map(&:user_id)).index_by(&:id)

      entries = results.map do |r|
        user = users[r.user_id]
        {
          user_id: r.user_id,
          display_name: user&.display_name,
          discord_id: user&.discord_id,
          count: r.visit_count.to_i
        }
      end
      assign_ranks(entries) { |e| e[:count] }
    end

    def duration_ranking(scope)
      results = scope
        .select("user_id, SUM(EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))) AS total_seconds")
        .group(:user_id)
        .order("total_seconds DESC")
        .limit(10)

      users = User.where(id: results.map(&:user_id)).index_by(&:id)

      entries = results.map do |r|
        user = users[r.user_id]
        {
          user_id: r.user_id,
          display_name: user&.display_name,
          discord_id: user&.discord_id,
          total_seconds: r.total_seconds.to_i
        }
      end
      assign_ranks(entries) { |e| e[:total_seconds] }
    end

    def find_user_rank(results, user_id)
      rank = 0
      prev_value = nil
      results.each_with_index do |r, i|
        value = yield(r)
        rank = i + 1 if value != prev_value
        return rank if r.user_id == user_id
        prev_value = value
      end
      nil
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
end
