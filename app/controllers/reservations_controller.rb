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
      @reservation.start_at = date.in_time_zone.change(hour: 10, min: 0)
      @reservation.end_at = date.in_time_zone.change(hour: 12, min: 0)
    end
  end

  def create
    # Combine date and time params to construct start_at and end_at
    date_str = params[:reservation][:date]
    start_time_str = params[:reservation][:start_time]
    end_time_str = params[:reservation][:end_time]

    if date_str.present? && start_time_str.present? && end_time_str.present?
      date = Date.parse(date_str)
      start_time = Time.parse(start_time_str)
      end_time = Time.parse(end_time_str)

      @reservation = Reservation.new
      @reservation.start_at = date.in_time_zone.change(hour: start_time.hour, min: start_time.min)
      @reservation.end_at = date.in_time_zone.change(hour: end_time.hour, min: end_time.min)
      @reservation.user = current_user
    else
      @reservation = Reservation.new(reservation_params)
      @reservation.user = current_user
    end

    if @reservation.save
      redirect_to reservations_path, notice: "予約を作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def reservation_params
    params.require(:reservation).permit(:start_at, :end_at)
  end
end
