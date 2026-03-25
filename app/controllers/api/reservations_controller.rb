module Api
  class ReservationsController < BaseController
    # Botアクセスのためユーザー認証はスキップし、代わりにAPI Key認証を行う
    skip_before_action :authenticate_user!
    before_action :authenticate_api_key!

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
        user: { only: [ :id, :username, :display_name, :discord_id, :avatar_url ] }
      }
    end

    # POST /api/reservations
    def create
      # TODO: Implement proper Authentication & Authorization (Issue #TBD)
      # Currently using MOCK AUTH for development.

      user = nil
      if params[:user_id].present?
        user = User.find_by(id: params[:user_id])
      elsif params[:discord_user_id].present?
        user = User.find_by(discord_id: params[:discord_user_id])
      end

      if user.nil?
        return render json: { error: "User not found (user_id or discord_user_id required)" }, status: :not_found
      end

      reservation = user.reservations.build(reservation_params)

      if reservation.save
        DiscordNotifier.notify(type: "reservation_created", data: DiscordNotifier.reservation_data(reservation))
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
      params.require(:reservation).permit(:start_at, :end_at, :purpose)
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
