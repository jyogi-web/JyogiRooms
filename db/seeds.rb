# 固定マスターデータ（全環境共通: roles, rooms, keys）
load Rails.root.join("db/seeds/master_data.rb")

# 環境別データ（development.rb など）
env_seed = Rails.root.join("db/seeds/#{Rails.env}.rb")
load env_seed if env_seed.exist?
