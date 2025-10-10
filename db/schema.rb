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

ActiveRecord::Schema[8.0].define(version: 2025_10_10_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "collaborators", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "user_id"], name: "index_collaborators_on_note_id_and_user_id", unique: true
    t.index ["note_id"], name: "index_collaborators_on_note_id"
    t.index ["user_id"], name: "index_collaborators_on_user_id"
  end

  create_table "forks", force: :cascade do |t|
    t.bigint "source_note_id", null: false
    t.bigint "target_note_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["source_note_id"], name: "index_forks_on_source_note_id"
    t.index ["target_note_id"], name: "index_forks_on_target_note_id", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.string "title", default: "", null: false
    t.bigint "owner_id", null: false
    t.bigint "head_version_id"
    t.string "visibility", default: "private", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["head_version_id"], name: "index_notes_on_head_version_id"
    t.index ["owner_id"], name: "index_notes_on_owner_id"
    t.index ["visibility"], name: "index_notes_on_visibility"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "author_id", null: false
    t.bigint "parent_version_id"
    t.string "summary", default: "", null: false
    t.text "content", null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "version_number", null: false
    t.index ["author_id"], name: "index_versions_on_author_id"
    t.index ["note_id", "created_at"], name: "index_versions_on_note_id_and_created_at"
    t.index ["note_id", "version_number"], name: "index_versions_on_note_id_and_version_number", unique: true
    t.index ["note_id"], name: "index_versions_on_note_id"
    t.index ["parent_version_id"], name: "index_versions_on_parent_version_id"
  end

  add_foreign_key "collaborators", "notes", on_delete: :cascade
  add_foreign_key "collaborators", "users", on_delete: :cascade
  add_foreign_key "forks", "notes", column: "source_note_id"
  add_foreign_key "forks", "notes", column: "target_note_id"
  add_foreign_key "notes", "users", column: "owner_id", on_delete: :restrict
  add_foreign_key "notes", "versions", column: "head_version_id"
  add_foreign_key "versions", "notes", on_delete: :cascade
  add_foreign_key "versions", "users", column: "author_id"
  add_foreign_key "versions", "versions", column: "parent_version_id"
end
