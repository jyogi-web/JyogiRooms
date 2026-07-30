module ApplicationHelper
  def format_jst_datetime(time)
    return nil unless time

    time.in_time_zone("Asia/Tokyo").strftime("%Y/%m/%d %H:%M")
  end
end
