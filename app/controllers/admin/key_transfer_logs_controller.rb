class Admin::KeyTransferLogsController < Admin::BaseController
  def index
    @key_transfer_logs = KeyTransferLog.includes(:room, :from_user, :to_user)
                                       .order(created_at: :desc)
                                       .limit(100)
  end

  def show
    @key_transfer_log = KeyTransferLog.includes(:room, :from_user, :to_user).find(params[:id])
  end
end
