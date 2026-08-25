class Admin::ViewLogsController < Admin::BaseController
  DAYS = 30
  RECENT_LIMIT = 100
  CATEGORIES = %w[room_status ranking stats].freeze

  def index
    @category = params[:category].presence_in(CATEGORIES)
    result = ViewLogStatsClient.fetch(days: DAYS, limit: RECENT_LIMIT, category: @category)

    unless result.ok
      @error = result.error
      @stats = nil
      return
    end

    @stats = result.data
    @days = DAYS
    @recent = build_recent_rows(@stats["recent"] || [])
  end

  private

  # D1 から返る user_id / discord_id を Rails のユーザーに解決して表示名を付ける
  def build_recent_rows(recent)
    user_ids = recent.filter_map { |r| r["user_id"] }.uniq
    discord_ids = recent.filter_map { |r| r["discord_id"] }.uniq

    users_by_id = User.where(id: user_ids).index_by(&:id)
    users_by_discord = User.where(discord_id: discord_ids).index_by(&:discord_id)

    recent.map do |row|
      user =
        if row["user_id"]
          users_by_id[row["user_id"]]
        elsif row["discord_id"]
          users_by_discord[row["discord_id"]]
        end

      {
        source: row["source"],
        category: row["category"],
        viewed_at: parse_time(row["viewed_at"]),
        display_name: user&.display_name,
        username: user&.username,
        raw_identity: row["user_id"] ? "user##{row["user_id"]}" : "discord:#{row["discord_id"]}"
      }
    end
  end

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
