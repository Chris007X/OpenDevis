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

ActiveRecord::Schema[8.1].define(version: 2026_03_13_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "artisan_categories", force: :cascade do |t|
    t.bigint "artisan_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_category_id", null: false
    t.index ["artisan_id", "work_category_id"], name: "index_artisan_categories_on_artisan_id_and_work_category_id", unique: true
    t.index ["artisan_id"], name: "index_artisan_categories_on_artisan_id"
    t.index ["work_category_id"], name: "index_artisan_categories_on_work_category_id"
  end

  create_table "artisans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "certifications"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "portfolio_url"
    t.string "postcode", null: false
    t.decimal "rating", precision: 3, scale: 2
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_artisans_on_email", unique: true
    t.index ["reset_password_token"], name: "index_artisans_on_reset_password_token", unique: true
  end

  create_table "bidding_requests", force: :cascade do |t|
    t.text "artisan_comment"
    t.bigint "artisan_id", null: false
    t.bigint "bidding_round_id", null: false
    t.datetime "created_at", null: false
    t.decimal "price_total", precision: 10, scale: 2
    t.bigint "replaced_by_id"
    t.datetime "responded_at"
    t.string "response_method"
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_category_id", null: false
    t.index ["artisan_id"], name: "index_bidding_requests_on_artisan_id"
    t.index ["bidding_round_id", "work_category_id", "artisan_id"], name: "index_bidding_requests_on_round_category_artisan", unique: true
    t.index ["bidding_round_id"], name: "index_bidding_requests_on_bidding_round_id"
    t.index ["token"], name: "index_bidding_requests_on_token", unique: true
    t.index ["work_category_id"], name: "index_bidding_requests_on_work_category_id"
  end

  create_table "bidding_rounds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deadline", null: false
    t.bigint "project_id", null: false
    t.integer "standing_level", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_bidding_rounds_on_project_id", unique: true
  end

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

  create_table "final_selections", force: :cascade do |t|
    t.boolean "ai_recommended", default: false, null: false
    t.bigint "bidding_request_id", null: false
    t.bigint "bidding_round_id", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_category_id", null: false
    t.index ["bidding_request_id"], name: "index_final_selections_on_bidding_request_id"
    t.index ["bidding_round_id", "work_category_id"], name: "idx_on_bidding_round_id_work_category_id_4aba6d8560", unique: true
    t.index ["bidding_round_id"], name: "index_final_selections_on_bidding_round_id"
    t.index ["work_category_id"], name: "index_final_selections_on_work_category_id"
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

  create_table "notifications", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.bigint "project_id"
    t.boolean "read", default: false, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_notifications_on_project_id"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "energy_rating"
    t.string "location_zip"
    t.string "name"
    t.text "photo_url"
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

  create_table "reference_prices", force: :cascade do |t|
    t.string "applicable_rooms"
    t.string "category_slug", null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.decimal "labor_price_exVAT", precision: 10, scale: 2, default: "0.0", null: false
    t.string "quantity_formula", default: "surface", null: false
    t.integer "sort_order", default: 0, null: false
    t.decimal "supply_price_exVAT", precision: 10, scale: 2, default: "0.0", null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.integer "vat_rate", default: 10, null: false
    t.index ["category_slug", "sort_order"], name: "idx_ref_prices_cat_sort"
    t.index ["category_slug"], name: "index_reference_prices_on_category_slug"
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
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
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

  add_foreign_key "artisan_categories", "artisans"
  add_foreign_key "artisan_categories", "work_categories"
  add_foreign_key "bidding_requests", "artisans"
  add_foreign_key "bidding_requests", "bidding_rounds"
  add_foreign_key "bidding_requests", "work_categories"
  add_foreign_key "bidding_rounds", "projects"
  add_foreign_key "documents", "projects"
  add_foreign_key "final_selections", "bidding_requests"
  add_foreign_key "final_selections", "bidding_rounds"
  add_foreign_key "final_selections", "work_categories"
  add_foreign_key "materials", "work_categories"
  add_foreign_key "notifications", "projects"
  add_foreign_key "notifications", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "rooms", "projects"
  add_foreign_key "work_items", "materials"
  add_foreign_key "work_items", "rooms"
  add_foreign_key "work_items", "work_categories"
end
