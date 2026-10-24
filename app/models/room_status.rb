# frozen_string_literal: true

# 部室状況のスナップショット（参照専用）
# - 1部室1レコードのみ存在する
# - 開閉・入退室のたびに RoomStateService / RoomEntryService が更新する
# - 状況確認（WebアプリとDiscord Bot）はこのテーブルのみを参照する
class RoomStatus < ApplicationRecord
  belongs_to :room
  belongs_to :opened_by, class_name: "User", optional: true

  validate :occupants_must_be_array_of_objects

  def normalized_occupants
    return [] unless occupants.is_a?(Array)

    occupants.filter_map do |entry|
      next unless entry.is_a?(Hash)

      user_id = entry["user_id"] || entry[:user_id]
      entered_at = entry["entered_at"] || entry[:entered_at]
      display_name = entry["display_name"] || entry[:display_name]
      next if user_id.blank?

      {
        "user_id" => user_id.to_i,
        "entered_at" => entered_at,
        "display_name" => display_name
      }
    end
  end

  private

  def occupants_must_be_array_of_objects
    unless occupants.is_a?(Array)
      errors.add(:occupants, "must be an array")
      return
    end

    invalid = occupants.any? do |entry|
      !entry.is_a?(Hash) || (entry["user_id"].blank? && entry[:user_id].blank?)
    end
    errors.add(:occupants, "must be an array of objects with user_id") if invalid
  end
end
