class Calendar::DayComponent < ViewComponent::Base
  def initialize(date:, current_month:, reservations_by_date:)
    @date = date
    @current_month = current_month
    @reservations_by_date = reservations_by_date
  end

  private

  def today?
    @date == Date.current
  end

  def current_month?
    @date.year == @current_month.year && @date.month == @current_month.month
  end

  def day_reservations
    @day_reservations ||= (@reservations_by_date[@date] || []).sort_by(&:start_at)
  end

  def past?
    @date < Date.current
  end

  def container_classes
    base = "relative bg-white min-h-[120px] p-1 md:p-2 flex flex-col gap-0.5 md:gap-1"

    if past?
      "#{base} bg-gray-100/50 text-gray-400 hover:bg-gray-100 transition-colors"
    else
      style = current_month? ? "hover:bg-gray-50 transition-colors group" : "opacity-50 bg-gray-50/30 hover:bg-gray-50"
      "#{base} #{style}"
    end
  end

  def date_circle_classes
    base = "text-sm rounded-full w-7 h-7 flex items-center justify-center font-medium"
    if today?
      "#{base} bg-primary text-white"
    elsif current_month?
      "#{base} text-gray-700"
    else
      "#{base} text-gray-400"
    end
  end
end
