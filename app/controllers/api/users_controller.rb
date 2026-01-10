# frozen_string_literal: true

module Api
  # ユーザー情報APIコントローラー
  class UsersController < BaseController
    # GET /api/users/me
    # 現在ログイン中のユーザー情報を取得
    def me
      unless user_signed_in?
        render json: { error: "\u672A\u30ED\u30B0\u30A4\u30F3" }, status: :unauthorized
        return
      end

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

    def logout
      sign_out
      reset_session
      render json: { message: "\u30ED\u30B0\u30A2\u30A6\u30C8\u3057\u307E\u3057\u305F\u3002" }, status: :ok
    end
  end
end
