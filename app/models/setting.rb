# frozen_string_literal: true

# アプリ全体の設定（シングルトンレコード。1件のみ使用）
# 例: 統計・ランキング機能の ON/OFF
class Setting < ApplicationRecord
  STATS_ENABLED_CACHE_KEY = "setting:stats_enabled"

  after_commit :clear_stats_enabled_cache, on: %i[create update destroy]

  # シングルトンレコードを取得（無ければ既定値で作成）
  def self.instance
    first_or_create!
  end

  # 統計・ランキング機能が有効か（頻繁に参照するためキャッシュ）
  def self.stats_enabled?
    Rails.cache.fetch(STATS_ENABLED_CACHE_KEY) { instance.stats_enabled }
  end

  private

  def clear_stats_enabled_cache
    Rails.cache.delete(STATS_ENABLED_CACHE_KEY)
  end
end
