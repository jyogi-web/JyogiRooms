class Admin::UsersController < Admin::BaseController
  def show
    @user = User.includes(:role, :access_tokens, :reservations, :keys, :nfc_card).find(params[:id])
    @roles = available_roles
  end

  def update
    @user = User.includes(:role, :access_tokens, :reservations, :keys, :nfc_card).find(params[:id])
    if current_user&.manager? && @user.admin?
      return redirect_to admin_user_path(@user), alert: "managerはadminユーザーのロールを変更できません"
    end
    if current_user&.manager? && assigning_admin_role?
      return redirect_to admin_user_path(@user), alert: "managerはadminロールを付与できません"
    end

    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "ユーザー「#{@user.display_name}」を更新しました"
    else
      @roles = available_roles
      render :show, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:role_id)
  end

  def available_roles
    roles = Role.order(:name)
    return roles unless current_user&.manager?

    roles.where.not(name: Role::ADMIN)
  end

  def assigning_admin_role?
    return false if params[:user].blank?

    role_id = params[:user][:role_id].presence
    return false if role_id.blank?

    Role.find_by(id: role_id)&.name == Role::ADMIN
  end
end
