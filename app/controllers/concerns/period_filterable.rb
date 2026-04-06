# frozen_string_literal: true

module PeriodFilterable
  extend ActiveSupport::Concern

  VALID_PERIODS = %w[today week month half_year year all].freeze

  private

  def period_date_range(period)
    now = Time.current.in_time_zone("Asia/Tokyo")
    case period
    when "today"
      now.beginning_of_day..now
    when "week"
      now.beginning_of_week(:monday)..now
    when "month"
      now.beginning_of_month..now
    when "half_year"
      6.months.ago.in_time_zone("Asia/Tokyo").beginning_of_day..now
    when "year"
      1.year.ago.in_time_zone("Asia/Tokyo").beginning_of_day..now
    when "all"
      nil
    end
  end
end
