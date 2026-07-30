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

ActiveRecord::Schema[8.1].define(version: 2026_06_06_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "access_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.boolean "revoked", default: false, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_access_tokens_on_expires_at"
    t.index ["token"], name: "index_access_tokens_on_token", unique: true
    t.index ["user_id", "revoked"], name: "index_access_tokens_on_user_id_and_revoked"
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "app_updates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.date "released_on", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["released_on"], name: "index_app_updates_on_released_on"
  end

  create_table "key_transfer_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_user_id", null: false
    t.bigint "room_id", null: false
    t.bigint "to_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_key_transfer_logs_on_created_at"
    t.index ["from_user_id"], name: "index_key_transfer_logs_on_from_user_id"
    t.index ["room_id", "created_at"], name: "index_key_transfer_logs_on_room_id_and_created_at"
    t.index ["to_user_id"], name: "index_key_transfer_logs_on_to_user_id"
  end

  create_table "keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "room_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["room_id", "user_id"], name: "index_keys_on_room_id_and_user_id", unique: true
    t.index ["room_id"], name: "index_keys_on_room_id"
    t.index ["user_id"], name: "index_keys_on_user_id"
  end

  create_table "nfc_cards", force: :cascade do |t|
    t.string "card_uid", null: false
    t.datetime "created_at", null: false
    t.string "student_id"
    t.string "student_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_uid"], name: "index_nfc_cards_on_card_uid", unique: true
    t.index ["user_id"], name: "index_nfc_cards_on_user_id", unique: true
  end

  create_table "nfc_registration_requests", force: :cascade do |t|
    t.string "card_uid"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "student_id"
    t.string "student_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_nfc_registration_requests_on_expires_at"
    t.index ["user_id"], name: "index_nfc_registration_requests_on_user_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_at", null: false
    t.string "purpose"
    t.datetime "start_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["start_at", "end_at"], name: "index_reservations_on_start_at_and_end_at"
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "room_sessions", force: :cascade do |t|
    t.datetime "closed_at"
    t.bigint "closed_by_id"
    t.datetime "created_at", null: false
    t.datetime "opened_at", null: false
    t.bigint "opened_by_id", null: false
    t.bigint "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_by_id"], name: "index_room_sessions_on_closed_by_id"
    t.index ["opened_by_id"], name: "index_room_sessions_on_opened_by_id"
    t.index ["room_id", "closed_at"], name: "index_room_sessions_on_room_id_and_closed_at"
    t.index ["room_id"], name: "index_room_sessions_on_room_id"
    t.index ["room_id"], name: "index_room_sessions_on_room_id_active_unique", unique: true, where: "(closed_at IS NULL)"
  end

  create_table "room_statuses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_open", default: false, null: false
    t.integer "occupant_count", default: 0, null: false
    t.jsonb "occupants", default: [], null: false
    t.datetime "opened_at"
    t.bigint "opened_by_id"
    t.bigint "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["opened_by_id"], name: "index_room_statuses_on_opened_by_id"
    t.index ["room_id"], name: "index_room_statuses_on_room_id", unique: true
  end

  create_table "room_visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "entered_at", null: false
    t.datetime "exited_at"
    t.bigint "room_id", null: false
    t.string "source", default: "web", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["room_id", "exited_at"], name: "index_room_visits_on_room_id_and_exited_at"
    t.index ["room_id"], name: "index_room_visits_on_room_id"
    t.index ["user_id", "exited_at"], name: "index_room_visits_on_user_id_and_exited_at"
    t.index ["user_id"], name: "index_room_visits_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "room_number", null: false
    t.datetime "updated_at", null: false
    t.index ["room_number"], name: "index_rooms_on_room_number", unique: true
  end

  create_table "scheduled_announcements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "hour", default: 20, null: false
    t.text "message", null: false
    t.integer "minute", default: 0, null: false
    t.datetime "updated_at", null: false
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
    t.bigint "role_id"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["discord_id"], name: "index_users_on_discord_id", unique: true
    t.index ["jyogi_user_id"], name: "index_users_on_jyogi_user_id", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  add_foreign_key "access_tokens", "users"
  add_foreign_key "key_transfer_logs", "rooms"
  add_foreign_key "key_transfer_logs", "users", column: "from_user_id"
  add_foreign_key "key_transfer_logs", "users", column: "to_user_id"
  add_foreign_key "keys", "rooms"
  add_foreign_key "keys", "users"
  add_foreign_key "nfc_cards", "users"
  add_foreign_key "nfc_registration_requests", "users"
  add_foreign_key "reservations", "users"
  add_foreign_key "room_sessions", "rooms"
  add_foreign_key "room_sessions", "users", column: "closed_by_id"
  add_foreign_key "room_sessions", "users", column: "opened_by_id"
  add_foreign_key "room_statuses", "rooms"
  add_foreign_key "room_statuses", "users", column: "opened_by_id"
  add_foreign_key "room_visits", "rooms"
  add_foreign_key "room_visits", "users"
  add_foreign_key "users", "roles"
end
