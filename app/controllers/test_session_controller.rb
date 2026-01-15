if Rails.env.test?
  class TestSessionController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :verify_authenticity_token

    def create
      user = User.find(params[:user_id])
      # Create a dummy access token
      sign_in(user, "mock_token_#{SecureRandom.hex(8)}")
      head :ok
    end
  end
end
