# frozen_string_literal: true

# jyogi-auth OAuth2設定
module JyogiAuth
  class Configuration
    attr_accessor :base_url, :client_id, :client_secret, :redirect_uri, :frontend_url

    def initialize
      @base_url = ENV.fetch('JYOGI_AUTH_URL')
      @client_id = ENV.fetch('CLIENT_ID')
      @client_secret = ENV.fetch('CLIENT_SECRET')
      @redirect_uri = ENV.fetch('REDIRECT_URI')
      @frontend_url = ENV.fetch('FRONTEND_URL')
    end

    # OAuth2認可エンドポイント
    def authorize_url
      "#{base_url}/oauth/authorize"
    end

    # OAuth2トークンエンドポイント
    def token_url
      "#{base_url}/oauth/token"
    end

    # ユーザー情報取得エンドポイント
    def user_info_url
      "#{base_url}/oauth/userinfo"
    end

    # トークン検証エンドポイント
    def verify_url
      "#{base_url}/api/verify"
    end

    # ログアウトエンドポイント
    def logout_url
      "#{base_url}/auth/logout"
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
