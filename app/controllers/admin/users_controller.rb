class Admin::UsersController < Admin::BaseController
  def show
    @user = User.includes(:role, :access_tokens, :reservations, :keys).find(params[:id])
  end
end
