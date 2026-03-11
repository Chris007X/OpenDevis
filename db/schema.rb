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

ActiveRecord::Schema[8.1].define(version: 2026_03_11_114142) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "file_name"
    t.string "file_type"
    t.text "file_url"
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at"
    t.index ["project_id"], name: "index_documents_on_project_id"
  end

  create_table "materials", force: :cascade do |t|
    t.string "brand"
    t.datetime "created_at", null: false
    t.decimal "public_price_exVAT", precision: 10, scale: 2
    t.string "reference"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.integer "vat_rate"
    t.bigint "work_category_id", null: false
    t.index ["work_category_id"], name: "index_materials_on_work_category_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "energy_rating"
    t.string "location_zip"
    t.text "property_url"
    t.integer "room_count"
    t.string "status"
    t.decimal "total_exVAT", precision: 10, scale: 2
    t.decimal "total_incVAT", precision: 10, scale: 2
    t.decimal "total_surface_sqm", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.decimal "perimeter_lm", precision: 10, scale: 2
    t.bigint "project_id", null: false
    t.decimal "surface_sqm", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "wall_height_m", precision: 10, scale: 2
    t.index ["project_id"], name: "index_rooms_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "auth_provider", default: "email"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "full_name"
    t.string "location"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "work_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "work_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label"
    t.bigint "material_id", null: false
    t.decimal "quantity", precision: 10, scale: 3
    t.bigint "room_id", null: false
    t.integer "standing_level"
    t.string "unit"
    t.decimal "unit_price_exVAT", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.integer "vat_rate"
    t.bigint "work_category_id", null: false
    t.index ["material_id"], name: "index_work_items_on_material_id"
    t.index ["room_id"], name: "index_work_items_on_room_id"
    t.index ["work_category_id"], name: "index_work_items_on_work_category_id"
  end

  add_foreign_key "documents", "projects"
  add_foreign_key "materials", "work_categories"
  add_foreign_key "projects", "users"
  add_foreign_key "rooms", "projects"
  add_foreign_key "work_items", "materials"
  add_foreign_key "work_items", "rooms"
  add_foreign_key "work_items", "work_categories"
end
