# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# jyogi-auth API連携クライアント
class JyogiAuthClient
  class Error < StandardError; end
  class NetworkError < Error; end
  class AuthenticationError < Error; end
  class ValidationError < Error; end

  TIMEOUT_SECONDS = 10

  # OAuth2認可URLを生成
  def self.authorization_url(state:)
    config = JyogiAuth.configuration
    uri = URI(config.authorize_url)
    params = {
      client_id: config.client_id,
      redirect_uri: config.redirect_uri,
      response_type: "code",
      state: state
    }
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end

  # 認可コードをアクセストークンと交換
  def self.exchange_code_for_token(code:)
    config = JyogiAuth.configuration
    uri = URI(config.token_url)

    params = {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: config.redirect_uri,
      client_id: config.client_id,
      client_secret: config.client_secret
    }

    Rails.logger.info "Token exchange request: POST #{uri}"
    Rails.logger.info "Token exchange params: #{params.except(:client_secret).inspect}"

    response = post_request(uri, params)
    Rails.logger.info "Token exchange response: #{response.code} #{response.message}"

    begin
      body_json = JSON.parse(response.body)
      masked_body = body_json.dup
      %w[access_token refresh_token].each do |key|
        masked_body[key] = "****" if masked_body.key?(key)
      end
      Rails.logger.info "Token exchange response body: #{masked_body.to_json}"
    rescue JSON::ParserError
      Rails.logger.warn "Token exchange response: Invalid JSON format"
    end

    parse_response(response)
  rescue JSON::ParserError => e
    raise ValidationError, "Invalid JSON response: #{e.message}"
  end

  # アクセストークンを使用してユーザー情報を取得
  def self.fetch_user_info(access_token:)
    config = JyogiAuth.configuration
    uri = URI(config.user_info_url)

    Rails.logger.info "Fetch user info request: GET #{uri}"
    Rails.logger.info "Access token (first 20 chars): #{access_token[0..19]}..."

    response = get_request(uri, access_token)
    Rails.logger.info "Fetch user info response: #{response.code} #{response.message}"
    Rails.logger.info "Fetch user info response body: #{response.body}"

    parse_response(response)
  rescue JSON::ParserError => e
    raise ValidationError, "Invalid JSON response: #{e.message}"
  end

  # トークンを検証
  def self.verify_token(access_token:)
    config = JyogiAuth.configuration
    uri = URI(config.verify_url)

    response = get_request(uri, access_token)
    parse_response(response)
  rescue JSON::ParserError => e
    raise ValidationError, "Invalid JSON response: #{e.message}"
  end

  # ログアウト（トークン無効化）
  def self.logout(access_token:)
    config = JyogiAuth.configuration
    uri = URI(config.logout_url)

    response = post_request(uri, {}, access_token)
    parse_response(response)
  rescue JSON::ParserError => e
    raise ValidationError, "Invalid JSON response: #{e.message}"
  end

  private_class_method def self.post_request(uri, params, access_token = nil)
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request["Authorization"] = "Bearer #{access_token}" if access_token
    request.body = URI.encode_www_form(params)

    execute_request(request, uri)
  end

  private_class_method def self.get_request(uri, access_token)
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{access_token}"

    execute_request(request, uri)
  end

  private_class_method def self.execute_request(request, uri)
    http = setup_http_client(uri)
    http.request(request)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise NetworkError, "Request timeout: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::HTTPBadResponse => e
    raise NetworkError, "Network error: #{e.message}"
  end

  private_class_method def self.setup_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    # SSL検証を環境変数で制御(デフォルトは有効)
    ssl_verify_enabled = ENV.fetch("JYOGI_SSL_VERIFY", "true") == "true"

    if http.use_ssl?
      http.verify_mode = ssl_verify_enabled ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.verify_hostname = ssl_verify_enabled
    end

    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS
    http
  end

  private_class_method def self.parse_response(response)
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPUnauthorized
      error_body = JSON.parse(response.body) rescue {}
      error_message = error_body["error"] || error_body["error_description"] || "Invalid or expired token"
      Rails.logger.error "Auth error response: #{response.body}"
      raise AuthenticationError, error_message
    when Net::HTTPBadRequest
      error_body = JSON.parse(response.body) rescue {}
      error_message = error_body["error"] || error_body["error_description"] || "Bad request"
      Rails.logger.error "Validation error response: #{response.body}"
      raise ValidationError, error_message
    else
      Rails.logger.error "Unexpected response #{response.code}: #{response.body}"
      raise Error, "HTTP #{response.code}: #{response.message}"
    end
  end
end
