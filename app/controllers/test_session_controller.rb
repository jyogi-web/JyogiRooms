class TestSessionController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :verify_authenticity_token

  def create
    # Identify environment again for double safety, though routes guard it.
    raise ActionController::RoutingError, 'Not Found' unless Rails.env.test?

    user = User.find(params[:user_id])
    # Create a dummy access token
    sign_in(user, "mock_token_#{SecureRandom.hex(8)}")
    head :ok
  end
end
