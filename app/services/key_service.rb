# 鍵に関する業務ロジックをまとめた Service
# - Controller から呼ばれる前提
# - トランザクション管理を行う
# - 失敗時は例外を投げ、ハンドリングは呼び出し元に委ねる
class KeyService
  # 現在の鍵持ちを取得する
  #
  # @param room_id [Integer]
  # @return [User, nil] 鍵が存在しない場合は nil
  def self.current_holder(room_id)
    Key.current_holder_by_room_id(room_id)
  end

  # 鍵を譲渡する
  #
  # @param room_id [Integer]
  # @param from_user [User] current_user を想定
  # @param to_user_id [Integer]
  #
  # @raise [ActiveRecord::RecordNotFound]
  # @raise [ActiveRecord::RecordInvalid]
  def self.transfer(room_id:, from_user:, to_user_id:)
    ActiveRecord::Base.transaction do
      # 1. 現在の鍵を取得
      #    from_user が鍵を持っていない場合は例外を投げる
      key = Key.lock.find_by!(
        room_id: room_id,
        user_id: from_user.id
      )

      # 2. 譲渡先ユーザーを取得
      to_user = User.find(to_user_id)

      # 3. 鍵の所有者を更新
      key.update!(user: to_user)

      # 4. 譲渡履歴を保存
      KeyTransferLog.create!(
        room_id: room_id,
        from_user: from_user,
        to_user: to_user
      )
    end
  end
end
