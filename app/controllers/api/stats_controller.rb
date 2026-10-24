# frozen_string_literal: true

module Api
  class StatsController < BaseController
    skip_before_action :authenticate_user!
    before_action :authenticate_api_key!
    before_action :require_stats_enabled, only: %i[ranking me visit_days]
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
      user, period, base_scope = load_user_and_scope
      return if performed?

      visit_days = base_scope
        .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")

      render json: {
        discord_id: user.discord_id,
        period: period,
        visit_days: visit_days
      }
    end

    # GET /api/stats/me?discord_user_id=xxx&room=all
    def me
      user, room, base_scope = load_user_and_scope
      return if performed?

      # 全体または指定部室の統計
      visit_days = base_scope
        .count("DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')")
      duration = base_scope
        .sum("EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))").to_i

      render json: {
        user: { id: user.id, display_name: user.display_name, discord_id: user.discord_id },
        room: room,
        total: { visit_days: visit_days, total_seconds: duration },
        rank: build_rank(user.id, room)
      }
    end

    private

    # 統計・ランキングが無効な場合は工事中を示すレスポンスを返す（Discord Bot が判別する）
    def require_stats_enabled
      return if Setting.stats_enabled?

      render json: { enabled: false, message: "現在工事中です" }, status: :ok
    end

def load_user_and_scope
      unless params[:discord_user_id].present?
        render json: { error: "discord_user_id is required." }, status: :bad_request
        return []
      end

      user = User.find_by(discord_id: params[:discord_user_id])
      unless user
        render json: { error: "User not found." }, status: :not_found
        return []
      end

      room_param = params[:room].presence || "all"
      scope = RoomVisit.where(user: user)
      if room_param != "all"
        room = Room.find_by(id: room_param)
        unless room
          render json: { error: "Room not found." }, status: :not_found
          return []
        end
        scope = scope.where(room: room)
      end

      [ user, room_param, scope ]
    end

    def build_rank(user_id, room_param)
      scope = room_param == "all" ? RoomVisit.all : RoomVisit.where(room_id: room_param)

      all_visit_counts = scope
        .group(:user_id)
        .select("user_id, COUNT(DISTINCT DATE(entered_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo')) AS visit_count")
        .order("visit_count DESC, user_id ASC")

      visit_rank = find_user_rank(all_visit_counts, user_id) { |r| r.visit_count.to_i }

      all_durations = scope
        .group(:user_id)
        .select("user_id, SUM(EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at))) AS total_seconds")
        .order("total_seconds DESC, user_id ASC")

      duration_rank = find_user_rank(all_durations, user_id) { |r| r.total_seconds.to_i }

      {
        visit: { position: visit_rank, total_users: all_visit_counts.length },
        duration: { position: duration_rank, total_users: all_durations.length }
      }
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
