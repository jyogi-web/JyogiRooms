# frozen_string_literal: true

# NFC Raspiからのタッチ処理を統括するサービス
# card_uidから自動で入室/退室/カード登録を判定
class NfcTouchService
  class TouchError < StandardError; end

  # @param room [Room]
  # @param card_uid [String]
  # @param card_data [Hash] { student_id:, student_name: } (optional)
  # @return [Hash] { action: String, user: User, ... }
  def self.process(room:, card_uid:, card_data: {})
    nfc_card = NfcCard.find_by(card_uid: card_uid)

    if nfc_card
      handle_registered_card(room: room, nfc_card: nfc_card)
    else
      handle_unregistered_card(card_uid: card_uid, card_data: card_data)
    end
  end

  # 登録済みカード: 入退室トグル
  def self.handle_registered_card(room:, nfc_card:)
    user = nfc_card.user
    result = RoomEntryService.toggle(room: room, user: user, source: "nfc")

    {
      action: result[:action],
      user: { id: user.id, display_name: user.display_name },
      room: { id: room.id, name: room.name },
      timestamp: Time.current.iso8601
    }
  end

  # 未登録カード: 登録待ちがあればcard_uidを保存
  def self.handle_unregistered_card(card_uid:, card_data: {})
    # 期限切れのリクエストをクリーンアップ
    NfcRegistrationRequest.expired.delete_all

    pending_request = NfcRegistrationRequest.pending.first
    raise TouchError, "未登録のカードです" unless pending_request

    pending_request.update!(
      card_uid: card_uid,
      student_id: card_data[:student_id],
      student_name: card_data[:student_name]
    )

    {
      action: "registration",
      user: { id: pending_request.user_id, display_name: pending_request.user.display_name },
      card_uid: card_uid,
      timestamp: Time.current.iso8601
    }
  end

  private_class_method :handle_registered_card, :handle_unregistered_card
end
