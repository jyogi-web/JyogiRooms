module Api
  class ReservationsController < ApplicationController
    skip_forgery_protection # API requests don't provide CSRF tokens usually

    # GET /api/reservations
    def index
      reservations = Reservation.all

      # Date filtering
      if params[:start_from].present?
        reservations = reservations.where('start_at >= ?', params[:start_from])
      end

      if params[:end_to].present?
        reservations = reservations.where('end_at <= ?', params[:end_to])
      end

      # Order by start time
      render json: reservations.order(start_at: :asc)
    end

    # POST /api/reservations
    def create
      # MOCK AUTH: In production, use current_user.reservations.build
      user = User.find_by(id: params[:user_id])
      
      if user.nil?
        return render json: { error: "User not found" }, status: :unprocessable_entity
      end

      reservation = user.reservations.build(reservation_params)

      if reservation.save
        render json: reservation, status: :created
      else
        render json: { errors: reservation.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/reservations/:id
    def destroy
      reservation = Reservation.find_by(id: params[:id])

      if reservation
        reservation.destroy
        head :no_content
      else
        render json: { error: "Reservation not found" }, status: :not_found
      end
    end

    private

    def reservation_params
      params.require(:reservation).permit(:start_at, :end_at)
    end
  end
end
