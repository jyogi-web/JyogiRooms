# frozen_string_literal: true

require "test_helper"

# ApplicationController のアプリ全体アクセス記録（category: "app"）のテスト
class AppAccessLoggingTest < ActionDispatch::IntegrationTest
  # RoomViewLogger.log_web_view を一時的に差し替えて呼び出しを記録する
  def capture_app_view_logs
    logged = []
    original = RoomViewLogger.method(:log_web_view)
    RoomViewLogger.define_singleton_method(:log_web_view) do |user, category: "room_status"|
      logged << [ user&.id, category ]
    end
    yield
    logged
  ensure
    RoomViewLogger.define_singleton_method(:log_web_view, original)
  end

  test "ログイン中のメンバー画面GETは category=app で記録される" do
    logged = capture_app_view_logs do
      sign_in_as(users(:one))
      get "/reservations"
    end

    assert_equal [ [ users(:one).id, "app" ] ], logged
  end

  test "未ログインのアクセスは記録されない" do
    logged = capture_app_view_logs do
      get "/reservations"
    end

    assert_empty logged
  end

  test "APIパスは記録されない" do
    logged = capture_app_view_logs do
      sign_in_as(users(:one))
      get "/api/users/me"
    end

    assert_empty logged
  end

  test "POSTリクエストは記録されない" do
    logged = capture_app_view_logs do
      sign_in_as(users(:one))
      post "/room_statuses/1/exit_room"
    end

    assert_empty logged
  end
end
