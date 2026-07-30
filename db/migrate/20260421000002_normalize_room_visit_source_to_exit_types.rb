# frozen_string_literal: true

class NormalizeRoomVisitSourceToExitTypes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE room_visits
      SET source = 'web'
      WHERE source = 'discord'
    SQL

    change_column_default :room_visits, :source, from: "nfc", to: "web"
  end

  def down
    change_column_default :room_visits, :source, from: "web", to: "nfc"
  end
end
