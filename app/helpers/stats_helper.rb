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
    unit_class = "text-sm font-normal"
    parts = []
    if hours > 0
      parts << hours.to_s
      parts << content_tag(:span, "時間", class: unit_class)
    end
    parts << minutes.to_s
    parts << content_tag(:span, "分", class: unit_class)
    safe_join(parts)
  end

  PERIOD_OPTIONS = [
    { value: "today", label: "今日" },
    { value: "week", label: "今週" },
    { value: "month", label: "今月" },
    { value: "half_year", label: "半年間" },
    { value: "year", label: "1年間" },
    { value: "all", label: "全期間" }
  ].freeze

  def period_label(period)
    PERIOD_OPTIONS.find { |o| o[:value] == period }&.dig(:label) || "全期間"
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
