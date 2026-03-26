# frozen_string_literal: true

module Api
  # ユーザー情報APIコントローラー
  class UsersController < BaseController
    # GET /api/users/me
    # 現在ログイン中のユーザー情報を取得
    # @return User [JSON] | エラーメッセージ
    def me
      render json: { 'user': format_user_data(current_user) }, status: :ok
    end

    # GET /api/users/:id
    # 指定IDのユーザー情報を取得
    # @param id [Integer] ユーザーID
    #
    # @return User [JSON] | エラーメッセージ
    def show
      # 1. パラメータからユーザーIDを取得
      user = User.find_by(id: params[:id])

      # 2. ユーザー情報をJSON形式で返す
      if user
        render json: { 'user': format_user_data(user) }, status: :ok
        # 受け取り側
        # {%= user_data = JSON.parse(response.body)["user"] %}
      else
        render json: { error: I18n.t("api.users.show.not_found") }, status: :not_found
      end
    end

    # GET /api/users
    # ユーザー一覧を取得
    # @return [Hash] { users: Array<User> } ユーザー情報の配列を含むハッシュ
    def index
      # TODO: ページネーション対応
      users = User.all
      render json: { users: users.map { |user| format_user_data(user) } }, status: :ok
    end

    # POST /api/users
    def create
      # TODO : 実装
      head :method_not_allowed
    end

    # PUT /api/users/:id
    def update
      # TODO : 実装
      head :method_not_allowed
    end

    # DELETE /api/users/:id
    def destroy
      # TODO : 実装
      head :method_not_allowed
    end

    private

    def format_user_data(user)
      {
        id: user.id,
        jyogi_user_id: user.jyogi_user_id,
        discord_id: user.discord_id,
        username: user.username,
        display_name: user.display_name,
        avatar_url: user.avatar_url,
        guild_roles: user.guild_roles,
        guild_nickname: user.guild_nickname,
        last_synced_at: user.last_synced_at,
        role: user.role&.name,
        is_admin: user.admin?
      }
    end
  end
end
