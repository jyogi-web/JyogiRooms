module ReservationsHelper
  def format_date_with_weekday(date)
    return "" if date.nil?
    "#{date.strftime('%Y年%m月%d日')} (#{%w[日 月 火 水 木 金 土][date.wday]})"
  end


  def format_time_short(time)
    return "" if time.nil?
    time.strftime("%H:%M")
  end

  def time_field_class(reservation, field_name)
    base_classes = "bg-white border border-gray-300 text-gray-900 text-sm sm:text-lg rounded-lg focus:ring-primary focus:border-primary block w-full max-w-full pl-8 sm:pl-10 p-2 sm:p-2.5"
    error_classes = "border-red-500 text-red-900 placeholder-red-700 focus:ring-red-500 focus:border-red-500"

    if reservation.errors[field_name].any?
      "#{base_classes} #{error_classes}"
    else
      base_classes
    end
  end
end
