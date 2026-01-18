class Admin::RolesController < Admin::BaseController
  def index
    @roles = Role.left_joins(:users).group(:id).select("roles.*, COUNT(users.id) AS users_count").order(:name)
    @users = User.includes(:role).order(:username)
  end

  def show
    @role = Role.includes(:users).find(params[:id])
    @users = @role.users
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
