# frozen_string_literal: true

class Admin::ScheduledAnnouncementsController < Admin::BaseController
  def edit
    @announcement = ScheduledAnnouncement.current
  end

  def update
    @announcement = ScheduledAnnouncement.current
    if @announcement.update(announcement_params)
      redirect_to edit_admin_scheduled_announcement_path(@announcement), notice: "施錠アナウンス設定を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def announcement_params
    params.require(:scheduled_announcement).permit(:message, :hour, :minute, :enabled)
  end
end
