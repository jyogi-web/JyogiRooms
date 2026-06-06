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
    { value: "week", label: "1週間" },
    { value: "month", label: "1ヶ月" },
    { value: "half_year", label: "半年間" },
    { value: "year", label: "1年間" },
    { value: "all", label: "全期間" }
  ].freeze

  def period_label(period)
    PERIOD_OPTIONS.find { |o| o[:value] == period }&.dig(:label) || "全期間"
  end

  def room_label(room_param, rooms)
    return "全部室" if room_param == "all"

    rooms.find { |r| r.id.to_s == room_param }&.name || "全部室"
  end

  def rank_medal(rank)
    case rank
    when 1 then "🥇"
    when 2 then "🥈"
    when 3 then "🥉"
    else rank.to_s
    end
  end

  def heatmap_color(level)
    case level
    when 0 then "bg-gray-100"
    when 1 then "bg-green-200"
    when 2 then "bg-green-400"
    when 3 then "bg-green-600"
    when 4 then "bg-green-800"
    else "bg-gray-100"
    end
  end

  def heatmap_tooltip_content(day_data)
    lines = [day_data[:date].strftime('%Y/%m/%d'), "合計: #{format_duration(day_data[:seconds])}"]
    day_data[:room_durations].each do |rd|
      lines << "#{rd[:room_name]}: #{format_duration(rd[:seconds])}"
    end
    lines.join("\n")
  end

  def heatmap_period_label(period)
    case period
    when "week"      then "1週間"
    when "month"     then "1ヶ月"
    when "half_year" then "半年間"
    when "year"      then "1年間"
    when "all"       then "1年間"
    else "1年間"
    end
  end
end
