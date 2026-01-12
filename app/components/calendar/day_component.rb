class Calendar::DayComponent < ViewComponent::Base
  def initialize(date:, current_month:, reservations:)
    @date = date
    @current_month = current_month
    @reservations = reservations
  end

  def render?
    true
  end

  private

  def is_today?
    @date == Date.current
  end

  def is_current_month?
    @date.month == @current_month.month
  end

  def day_reservations
    @reservations.select { |r| r.start_at.to_date == @date }
                 .sort_by(&:start_at)
  end

  def container_classes
    base = "relative bg-white min-h-[120px] p-2 hover:bg-gray-50 transition-colors group flex flex-col gap-1"
    opacity = is_current_month? ? "" : "opacity-50 bg-gray-50/30"
    "#{base} #{opacity}"
  end

  def date_circle_classes
    base = "text-sm rounded-full w-7 h-7 flex items-center justify-center font-medium"
    if is_today?
      "#{base} bg-primary text-white"
    elsif is_current_month?
      "#{base} text-gray-700"
    else
      "#{base} text-gray-400"
    end
  end
end
