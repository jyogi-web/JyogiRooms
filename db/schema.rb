# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_10_112250) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "reservations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_at", null: false
    t.datetime "start_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["start_at", "end_at"], name: "index_reservations_on_start_at_and_end_at"
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "discord_id"
    t.string "display_name"
    t.string "guild_nickname"
    t.jsonb "guild_roles", default: {}
    t.string "jyogi_user_id", limit: 36
    t.datetime "last_synced_at"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["discord_id"], name: "index_users_on_discord_id", unique: true
    t.index ["jyogi_user_id"], name: "index_users_on_jyogi_user_id", unique: true
  end

  add_foreign_key "reservations", "users"
end
