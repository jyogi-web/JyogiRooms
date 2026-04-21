# frozen_string_literal: true

class AddManagerRole < ActiveRecord::Migration[8.1]
  class Role < ActiveRecord::Base
    self.table_name = "roles"
  end

  def up
    Role.find_or_create_by!(name: "manager")
  end

  def down
    manager_role = Role.find_by(name: "manager")
    return unless manager_role

    member_role = Role.find_by(name: "member")
    if member_role
      execute <<~SQL
        UPDATE users
        SET role_id = #{member_role.id}
        WHERE role_id = #{manager_role.id}
      SQL
    end

    manager_role.destroy!
  end
end
