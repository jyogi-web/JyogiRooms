class Admin::SettingsController < Admin::BaseController
  before_action :require_developer_admin!

  def edit
    @setting = Setting.instance
  end

  def update
    @setting = Setting.instance
    if @setting.update(setting_params)
      redirect_to edit_admin_settings_path, notice: "設定を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:setting).permit(:stats_enabled)
  end
end
