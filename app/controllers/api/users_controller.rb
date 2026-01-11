# frozen_string_literal: true

module Api
  # ユーザー情報APIコントローラー
  class UsersController < BaseController
    # ログイン中のユーザー情報取得
    # NOTE: 今後の拡張に備えて認証を必須化
    # 編集について
    # https://github.com/jyogi-web/JyogiRooms/pull/60#discussion_r2678899818
    before_action :authenticate_user!, only: %i[me logout]

    # GET /api/users/me
    # 現在ログイン中のユーザー情報を取得
    def me
      user = current_user

      user_data = {
        id: user.id,
        jyogi_user_id: user.jyogi_user_id,
        discord_id: user.discord_id,
        username: user.username,
        display_name: user.display_name,
        avatar_url: user.avatar_url,
        guild_roles: user.guild_roles,
        guild_nickname: user.guild_nickname,
        last_synced_at: user.last_synced_at
      }

      render json: user_data, status: :ok
    end

    # DELETE /api/users/logout
    # ログアウト処理
    def logout
      sign_out
      render json: { message: I18n.t("api.users.logout.success") }, status: :ok
    end
  end
end
