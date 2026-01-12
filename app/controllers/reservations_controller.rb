class ReservationsController < ApplicationController
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

    @reservations_by_date = @reservations.group_by { |r| r.start_at.to_date }
  end

  def new
    @reservation = Reservation.new
    # Handle date parameter for pre-filling
    if params[:date].present?
      date = Date.parse(params[:date]) rescue Date.current
      @reservation.reservation_date = date
      @reservation.start_time = "10:00"
      @reservation.end_time = "12:00"

      # Fetch existing reservations for this day to display in the view
      @existing_reservations = Reservation.includes(:user)
                                          .where(start_at: date.beginning_of_day..date.end_of_day)
                                          .order(:start_at)
    else
      @existing_reservations = []
    end
  end

  def create
    @reservation = Reservation.new(reservation_params)
    @reservation.user = current_user

    # Guard for missing user (though normally authenticated)
    if @reservation.user.nil?
      redirect_to root_path, alert: "ログインしてください"
      return
    end

    if @reservation.save
      redirect_to reservations_path, notice: "予約を作成しました"
    else
      # Re-populate existing reservations for the view
      if @reservation.reservation_date.present?
         date = @reservation.reservation_date
         @existing_reservations = Reservation.includes(:user)
                                             .where(start_at: date.beginning_of_day..date.end_of_day)
                                             .order(:start_at)
      else
        @existing_reservations = []
      end
      render :new, status: :unprocessable_entity
    end
  end

  private

  def reservation_params
    params.require(:reservation).permit(:start_at, :end_at, :reservation_date, :start_time, :end_time)
  end
end
