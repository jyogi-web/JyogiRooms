# frozen_string_literal: true

module StatsHelper
  def format_duration(total_seconds)
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    if hours > 0
      "#{hours}時間#{minutes}分"
    else
      "#{minutes}分"
    end
  end

  def year_label(year)
    year == "all" ? "全期間" : "#{year}年度"
  end

  def rank_medal(index)
    case index
    when 0 then "🥇"
    when 1 then "🥈"
    when 2 then "🥉"
    else "#{index + 1}"
    end
  end
end
