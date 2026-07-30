# frozen_string_literal: true

class NfcCardsController < ApplicationController
  before_action :authenticate_user!

  # GET /nfc_cards
  def index
    @nfc_card = current_user.nfc_card
  end

  # DELETE /nfc_cards/:id
  def destroy
    card = NfcCard.find(params[:id])

    if card.user_id != current_user.id
      redirect_to nfc_cards_path, alert: "権限がありません"
      return
    end

    card.destroy!
    redirect_to nfc_cards_path, notice: "学生証を削除しました"
  rescue ActiveRecord::RecordNotFound
    redirect_to nfc_cards_path, alert: "学生証が見つかりません"
  end
end
