module ReservationsHelper
  def format_date_with_weekday(date)
    return "" if date.nil?
    "#{date.strftime('%Y年%m月%d日')} (#{%w(日 月 火 水 木 金 土)[date.wday]})"
  end
end
