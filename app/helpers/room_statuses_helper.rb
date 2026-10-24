# frozen_string_literal: true

module RoomStatusesHelper
  def exit_source_label(source)
    case source
    when "nfc"
      "NFC"
    when "web"
      "Web"
    when "forced"
      "代理退室"
    when "room_close"
      "一斉退室"
    else
      "不明"
    end
  end

  def exit_source_badge(source, extra_classes: "")
    classes = [ "inline-block px-1.5 py-0.5 bg-gray-100 text-gray-600 text-xs font-medium rounded", extra_classes.presence ].compact.join(" ")
    content_tag(:span, exit_source_label(source), class: classes)
  end
end
