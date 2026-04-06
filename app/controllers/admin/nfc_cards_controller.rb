# frozen_string_literal: true

class Admin::NfcCardsController < Admin::BaseController
  def index
    @nfc_cards = NfcCard.includes(:user).order(created_at: :desc)
  end
end
