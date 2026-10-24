# frozen_string_literal: true

class Admin::AppUpdatesController < Admin::BaseController
  before_action :require_developer_admin!
  before_action :set_app_update, only: %i[edit update destroy]

  def index
    @app_updates = AppUpdate.order(released_on: :desc)
  end

  def new
    @app_update = AppUpdate.new(released_on: Date.current)
  end

  def create
    @app_update = AppUpdate.new(app_update_params)
    if @app_update.save
      redirect_to admin_app_updates_path, notice: "「#{@app_update.title}」を追加しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @app_update.update(app_update_params)
      redirect_to admin_app_updates_path, notice: "「#{@app_update.title}」を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @app_update.destroy!
    redirect_to admin_app_updates_path, notice: "削除しました"
  end

  private

  def set_app_update
    @app_update = AppUpdate.find(params[:id])
  end

  def app_update_params
    params.require(:app_update).permit(:title, :description, :released_on)
  end
end
