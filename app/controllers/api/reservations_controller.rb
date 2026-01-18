module Api
  class ReservationsController < BaseController
    # Botアクセスのためユーザー認証はスキップし、代わりにAPI Key認証を行う
    skip_before_action :authenticate_user!, only: [ :index ]
    before_action :authenticate_api_key!, only: [ :index ]

    # GET /api/reservations
    def index
      # TODO: Implement Authentication - currently returns all reservations
      reservations = Reservation.all

      # Date filtering
      if params[:start_from].present?
        start_time = parse_time(params[:start_from])
        return render_error("Invalid start_from") unless start_time

        reservations = reservations.where("start_at >= ?", start_time)
      end

      if params[:end_to].present?
        end_time = parse_time(params[:end_to])
        return render_error("Invalid end_to") unless end_time

        reservations = reservations.where("end_at <= ?", end_time)
      end

      # Order by start time
      render json: reservations.order(start_at: :asc), include: {
        user: { only: [:id, :username, :display_name, :discord_id, :avatar_url] }
      }
    end

    # POST /api/reservations
    def create
      # TODO: Implement proper Authentication & Authorization (Issue #TBD)
      # Currently using MOCK AUTH for development.

      unless params[:user_id].present?
        return render json: { error: "user_id parameter is required" }, status: :bad_request
      end

      user = User.find_by(id: params[:user_id])

      if user.nil?
        return render json: { error: "User not found" }, status: :not_found
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
        if reservation.destroy
          head :no_content
        else
          render json: { errors: reservation.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: "Reservation not found" }, status: :not_found
      end
    end

    private

    def reservation_params
      params.require(:reservation).permit(:start_at, :end_at)
    end

    def parse_time(string)
      Time.zone.parse(string)
    rescue ArgumentError
      nil
    end

    def render_error(message)
      render json: { error: message }, status: :bad_request
    end
  end
end
