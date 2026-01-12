class ReservationsController < ApplicationController
  def index
    # Will be implemented in the next step with Custom Calendar logic
    @reservations = Reservation.includes(:user).all
  end

  def new
    @reservation = Reservation.new
    # Handle date parameter for pre-filling
    if params[:date].present?
      date = Date.parse(params[:date])
      @reservation.reservation_date = date
      @reservation.start_time = "10:00"
      @reservation.end_time = "12:00"
      # Also set actual attributes for display if needed, or rely on virtuals
    end
  end

  def create
    @reservation = Reservation.new(reservation_params)
    @reservation.user = current_user

    if @reservation.save
      redirect_to reservations_path, notice: "予約を作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def reservation_params
    params.require(:reservation).permit(:start_at, :end_at, :reservation_date, :start_time, :end_time)
  end
end
