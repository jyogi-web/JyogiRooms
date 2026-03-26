module NavigationHelper
  def nav_items
    items = [
      { path: root_path, icon: :home, label: "ホーム", active: current_page?(root_path) },
      { path: room_statuses_path, icon: :door, label: "部室状況", active: current_page?(room_statuses_path) },
      { path: reservations_path, icon: :calendar, label: "部室予約", active: current_page?(reservations_path) },
      { path: keys_path, icon: :key, label: "鍵管理", active: current_page?(keys_path) }
    ]

    # 管理者のみ管理画面へのリンクを表示
    if current_user&.admin?
      items << { path: admin_roles_path, icon: :shield, label: "管理画面", active: controller_path.start_with?("admin/") }
    end

    items
  end

  def nav_icon(name, classes)
    path_d = case name
    when :home
               "M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
    when :calendar
               "M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5"
    when :key
               "M15.75 5.25a3 3 0 0 1 3 3m3 0a6 6 0 0 1-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1 1 21.75 8.25Z"
    when :shield
               "M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z"
    when :door
               "M6 21V3h12v18M6 3h12M6 21h12M15 12a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"

    end

    content = tag.path(d: path_d, stroke_linecap: "round", stroke_linejoin: "round")

    tag.svg(content, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", stroke_width: "1.5", stroke: "currentColor", class: classes)
  end

  # ユーザーのロール表示バッジを生成
  # @param user [User] 対象ユーザー
  # @param size [Symbol] バッジサイズ (:sm, :base)
  # @return [ActiveSupport::SafeBuffer] HTML バッジ
  def user_role_badge(user, size = :base)
    if user.admin?
      label = "admin"
      badge_class = "bg-red-100 text-red-700"
    elsif user.role
      label = user.role.name
      badge_class = "bg-blue-100 text-blue-700"
    else
      label = "未設定"
      badge_class = "bg-gray-100 text-gray-700"
    end

    size_class = size == :sm ? "text-xs" : "text-sm"
    content_tag(:span, label, class: "inline-block px-3 py-1 #{badge_class} #{size_class} font-semibold rounded-full")
  end
end
