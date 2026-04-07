# frozen_string_literal: true

module Api
  # NFC登録API（Webアプリから利用）
  class NfcRegistrationsController < BaseController
    before_action :authenticate_user!
    before_action :set_registration, only: %i[show confirm destroy]

    # POST /api/nfc_registrations
    def create
      if current_user.nfc_card.present?
        return render json: { error: "既にカードが登録されています" }, status: :unprocessable_entity
      end

      # 期限切れのリクエストをクリーンアップ
      NfcRegistrationRequest.expired.delete_all

      registration = current_user.nfc_registration_requests.build(
        expires_at: 1.minute.from_now
      )

      if registration.save
        render json: registration_json(registration), status: :created
      else
        render json: { errors: registration.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # GET /api/nfc_registrations/:id
    def show
      render json: registration_json(@registration)
    end

    # PATCH /api/nfc_registrations/:id/confirm
    def confirm
      if @registration.expired?
        return render json: { error: "登録リクエストの有効期限が切れています" }, status: :unprocessable_entity
      end

      unless @registration.completed?
        return render json: { error: "カードがまだ読み取られていません" }, status: :unprocessable_entity
      end

      if @registration.student_id.blank? || @registration.student_name.blank?
        return render json: { error: "学生証以外のカードは登録できません。学生証をかざしてください。" }, status: :unprocessable_entity
      end

      # 既に登録済みのカードでないか確認
      if NfcCard.exists?(card_uid: @registration.card_uid)
        return render json: { error: "このカードは既に登録されています" }, status: :unprocessable_entity
      end

      begin
        NfcCard.create!(
          user: current_user,
          card_uid: @registration.card_uid,
          student_id: @registration.student_id,
          student_name: @registration.student_name
        )
      rescue ActiveRecord::RecordNotUnique
        return render json: { error: "このカードは既に登録されています" }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        return render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end

      @registration.destroy!
      render json: { message: "学生証を登録しました" }, status: :ok
    end

    # DELETE /api/nfc_registrations/:id
    def destroy
      @registration.destroy!
      head :no_content
    end

    private

    def set_registration
      @registration = current_user.nfc_registration_requests.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "登録リクエストが見つかりません" }, status: :not_found
    end

    def registration_json(registration)
      {
        id: registration.id,
        user_id: registration.user_id,
        card_uid: registration.card_uid,
        student_id: registration.student_id,
        student_name: registration.student_name,
        expires_at: registration.expires_at.iso8601,
        expired: registration.expired?,
        pending: registration.pending?,
        completed: registration.completed?
      }
    end
  end
end
