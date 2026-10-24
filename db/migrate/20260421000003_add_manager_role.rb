# frozen_string_literal: true

class AddManagerRole < ActiveRecord::Migration[8.1]
  class Role < ActiveRecord::Base
    self.table_name = "roles"
  end

  class User < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    Role.find_or_create_by!(name: "manager")
  end

  def down
    ActiveRecord::Base.transaction do
      manager_role = Role.find_by(name: "manager")
      return unless manager_role

      member_role = Role.find_by(name: "member")
      raise ActiveRecord::IrreversibleMigration, "memberロールが存在しないためmanagerロールを安全に巻き戻せません" if member_role.nil?

      User.where(role_id: manager_role.id).update_all(role_id: member_role.id, updated_at: Time.current)
      manager_role.destroy!
    end
  end
end
