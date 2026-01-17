class Admin::RolesController < Admin::BaseController
  def index
    @roles = Role.includes(:users).order(:name)
    @users = User.includes(:role).order(:username)
  end

  def show
    @role = Role.includes(:users).find(params[:id])
  end

  def update
    @role = Role.find(params[:id])
    if @role.update(role_params)
      redirect_to admin_roles_path, notice: "ロール「#{@role.name}」を更新しました"
    else
      redirect_to admin_roles_path, alert: "ロールの更新に失敗しました"
    end
  end

  private

  def role_params
    params.require(:role).permit(:name)
  end
end
