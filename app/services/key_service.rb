# 鍵に関する業務ロジックをまとめた Service
# - Controller から呼ばれる前提
# - トランザクション管理を行う
# - 失敗時は例外を投げ、ハンドリングは呼び出し元に委ねる
class KeyService
  # 譲渡に関する業務例外
  class TransferError < StandardError; end

  # 鍵を譲渡する
  #
  # @param room_id [Integer]
  # @param from_user [User] current_user を想定
  # @param to_user_id [Integer]
  #
  # @raise [ActiveRecord::RecordNotFound]
  # @raise [ActiveRecord::RecordInvalid]
  # @raise [KeyService::TransferError]
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

      # 2.5 譲渡先がすでに同室の鍵を保持している場合はエラー
      if Key.exists?(room_id: room_id, user_id: to_user.id)
        raise TransferError, "譲渡先ユーザーは既にこの部屋の鍵を所持しています"
      end

      # 3. 鍵の所有者を更新
      key.update!(user: to_user)

      # 4. 譲渡履歴を保存
      KeyTransferLog.create!(
        room_id: room_id,
        from_user: from_user,
        to_user: to_user
      )
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
    raise TransferError, "譲渡先ユーザーは既にこの部屋の鍵を所持しています" if e.message.match?(/unique|uniq|duplicate/i)
    raise
  end

  # 未割り当ての鍵をユーザーに割り当てる（管理者用）
  #
  # @param room_id [Integer]
  # @param to_user_id [Integer]
  #
  # @raise [ActiveRecord::RecordNotFound]
  # @raise [KeyService::TransferError]
  def self.assign(room_id:, to_user_id:)
    ActiveRecord::Base.transaction do
      # 1. 未割り当ての鍵を取得
      key = Key.lock.find_by(room_id: room_id, user_id: nil)
      raise TransferError, "この部屋には未割り当ての鍵がありません" unless key

      # 2. 割り当て先ユーザーを取得
      to_user = User.find(to_user_id)

      # 3. 割り当て先がすでに同室の鍵を保持している場合はエラー
      if Key.exists?(room_id: room_id, user_id: to_user.id)
        raise TransferError, "このユーザーは既にこの部屋の鍵を所持しています"
      end

      # 4. 鍵の所有者を更新
      key.update!(user: to_user)
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
    raise TransferError, "このユーザーは既にこの部屋の鍵を所持しています" if e.message.match?(/unique|uniq|duplicate/i)
    raise
  end

  # 割り当て済みの鍵を未割り当てに戻す（管理者用）
  #
  # @param room_id [Integer]
  # @param user_id [Integer]
  #
  # @raise [ActiveRecord::RecordNotFound]
  # @raise [KeyService::TransferError]
  def self.unassign(room_id:, user_id:)
    ActiveRecord::Base.transaction do
      key = Key.lock.find_by!(room_id: room_id, user_id: user_id)
      key.update!(user: nil)
    end
  end
end
