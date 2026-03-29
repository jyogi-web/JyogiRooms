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

  def format_duration_styled(total_seconds)
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    parts = []
    parts << "#{hours}<span class=\"text-sm font-normal\">時間</span>" if hours > 0
    parts << "#{minutes}<span class=\"text-sm font-normal\">分</span>"
    parts.join.html_safe
  end

  def year_label(year)
    year == "all" ? "全期間" : "#{year}年度"
  end

  def available_fiscal_years(first_year = 2025)
    today = Time.current.in_time_zone("Asia/Tokyo").to_date
    current = today.month >= 4 ? today.year : today.year - 1
    (first_year..current).to_a
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
