# frozen_string_literal: true

module Api
  # API共通ベースコントローラー
  class BaseController < ApplicationController
    include ErrorRenderable
    include JyogiAuthenticatable

    # レスポンスをJSON形式に設定
    before_action :set_json_format

    private

    def set_json_format
      request.format = :json
    end

    # API Key認証
    def authenticate_api_key!
      api_key = request.headers["X-Api-Key"]
      # 環境変数が未設定の場合は認証不能としてエラーにする（セキュリティ事故防止）
      return render_unauthorized("Server configuration error") if ENV["API_ACCESS_TOKEN"].blank?

      unless api_key && ActiveSupport::SecurityUtils.secure_compare(api_key, ENV["API_ACCESS_TOKEN"])
        render_unauthorized("Invalid API Key")
      end
    end

    def render_unauthorized(message)
      render json: { error: message }, status: :unauthorized
    end
  end
end
