# frozen_string_literal: true

module Api
  # API共通ベースコントローラー
  class BaseController < ApplicationController
    include ErrorRenderable
    include JyogiAuthenticatable

    # CSRF保護を無効化（APIはトークンベース認証）
    skip_before_action :verify_authenticity_token

    # レスポンスをJSON形式に設定
    before_action :set_json_format

    private

    def set_json_format
      request.format = :json
    end
  end
end
