# frozen_string_literal: true

class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      # 統計・ランキング機能の有効/無効（既定は有効＝従来どおり）
      t.boolean :stats_enabled, null: false, default: true

      t.timestamps
    end
  end
end
