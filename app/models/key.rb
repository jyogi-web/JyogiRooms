class Key < ApplicationRecord
  belongs_to :user
  belongs_to :room

  # 指定した room_id の現在の鍵持ちを返す
  # 鍵が未登録の場合は nil を返す
  def self.current_holder_by_room_id(room_id)
    find_by(room_id: room_id)&.user
  end
end
