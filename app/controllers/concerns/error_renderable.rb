# frozen_string_literal: true

# エラーレスポンス処理用コンサーン
module ErrorRenderable
  extend ActiveSupport::Concern

  included do
    rescue_from JyogiAuthClient::NetworkError, with: :handle_network_error
    rescue_from JyogiAuthClient::AuthenticationError, with: :handle_authentication_error
    rescue_from JyogiAuthClient::ValidationError, with: :handle_validation_error
    rescue_from JyogiAuthClient::Error, with: :handle_generic_error
  end

  private

  def handle_network_error(exception)
    Rails.logger.error "Network error: #{exception.message}"
    render json: { error: "サービスに接続できません。しばらく経ってから再度お試しください。" },
           status: :service_unavailable
  end

  def handle_authentication_error(exception)
    Rails.logger.warn "Authentication error: #{exception.message}"
    clear_session
    render json: { error: "認証に失敗しました。再度ログインしてください。" },
           status: :unauthorized
  end

  def handle_validation_error(exception)
    Rails.logger.warn "Validation error: #{exception.message}"
    render json: { error: "不正なリクエストです。" },
           status: :bad_request
  end

  def handle_generic_error(exception)
    Rails.logger.error "Generic error: #{exception.message}"
    render json: { error: "エラーが発生しました。" },
           status: :internal_server_error
  end

  def clear_session
    reset_session
    @current_user = nil
  end
end
