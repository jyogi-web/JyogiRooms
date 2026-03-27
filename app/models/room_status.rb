# frozen_string_literal: true

# 部室状況のスナップショット（参照専用）
# - 1部室1レコードのみ存在する
# - 開閉・入退室のたびに RoomStateService / RoomEntryService が更新する
# - 状況確認（WebアプリとDiscord Bot）はこのテーブルのみを参照する
class RoomStatus < ApplicationRecord
  belongs_to :room
  belongs_to :opened_by, class_name: "User", optional: true
end
