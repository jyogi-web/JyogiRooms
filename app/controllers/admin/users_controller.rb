class Admin::UsersController < Admin::BaseController
  def show
    @user = User.includes(:role, :access_tokens, :reservations, :keys, :nfc_card).find(params[:id])
    @roles = Role.order(:name)
  end

  def update
    @user = User.includes(:role, :access_tokens, :reservations, :keys, :nfc_card).find(params[:id])
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "ユーザー「#{@user.display_name}」を更新しました"
    else
      @roles = Role.order(:name)
      render :show, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:role_id)
  end
end
