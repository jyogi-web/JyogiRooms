class ReservationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_reservation, only: [ :edit, :update, :destroy ]
  before_action :ensure_owner, only: [ :edit, :update, :destroy ]

  def index
    # Determine the month to display
    @current_month = begin
      params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
    rescue ArgumentError
      Date.current.beginning_of_month
    end

    # Calculate the start and end of the calendar grid (including padding days)
    start_date = @current_month.beginning_of_month.beginning_of_week(:sunday)
    end_date = @current_month.end_of_month.end_of_week(:sunday)

    @calendar_days = (start_date..end_date).to_a

    # Fetch reservations for the visible range
    # eager_load user for performance
    @reservations = Reservation.includes(:user)
                               .where(start_at: start_date.beginning_of_day..end_date.end_of_day)
                               .order(:start_at)

    # Group by date for efficient access in the view (avoiding N+1)
    @reservations_by_date = @reservations.group_by { |r| r.start_at.to_date }
  end

  def new
    @reservation = Reservation.new

    # Safe date parsing for pre-filling the form
    if params[:date].present?
      date = begin
        Date.parse(params[:date])
      rescue ArgumentError
        Date.current
      end
      @reservation.reservation_date = date
      @existing_reservations = fetch_existing_reservations(date)
    else
      @existing_reservations = []
    end
  end

  def create
    @reservation = Reservation.new(reservation_params)
    @reservation.user = current_user

    if @reservation.save
      redirect_to reservations_path, notice: "予約を作成しました"
    else
      # Re-populate existing reservations for the view
      @existing_reservations = fetch_existing_reservations(@reservation.reservation_date)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Populate virtual attributes for form pre-filling
    @reservation.reservation_date = @reservation.start_at.to_date
    @reservation.start_time = @reservation.start_at.strftime("%H:%M")
    @reservation.end_time = @reservation.end_at.strftime("%H:%M")

    @existing_reservations = fetch_existing_reservations(@reservation.reservation_date, exclude_id: @reservation.id)
  end

  def update
    if @reservation.update(reservation_params)
      redirect_to reservations_path, notice: "予約を更新しました"
    else
      # Use original date if available (in case of date change failure), otherwise current input date
      date = @reservation.start_at_was&.to_date || @reservation.reservation_date
      @existing_reservations = fetch_existing_reservations(date, exclude_id: @reservation.id)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @reservation.destroy
      redirect_to reservations_path, notice: "予約を削除しました", status: :see_other
    else
      redirect_to reservations_path, alert: "予約の削除に失敗しました"
    end
  end

  private

  def reservation_params
    permitted = [ :start_time, :end_time, :purpose ]
    permitted << :reservation_date if [ "create", "new" ].include?(action_name)
    params.require(:reservation).permit(permitted)
  end

  def fetch_existing_reservations(date, exclude_id: nil)
    return [] unless date.present?

    query = Reservation.includes(:user)
                       .where(start_at: date.beginning_of_day..date.end_of_day)

    query = query.where.not(id: exclude_id) if exclude_id

    query.order(:start_at)
  end

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end

  def ensure_owner
    unless @reservation.user == current_user
      redirect_to reservations_path, alert: "他のユーザーの予約は編集・削除できません" and return
    end
  end
end
