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

ActiveRecord::Schema[8.1].define(version: 2026_10_17_080100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "name"], name: "index_accounts_on_category_and_name", unique: true
    t.check_constraint "category::text = ANY (ARRAY['asset'::character varying, 'liability'::character varying, 'equity'::character varying]::text[])", name: "valid_account_category"
  end

  create_table "answers", force: :cascade do |t|
    t.bigint "quiz_run_question_id", null: false
    t.bigint "choice_id", null: false
    t.datetime "answered_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["choice_id"], name: "index_answers_on_choice_id"
    t.index ["quiz_run_question_id"], name: "index_answers_on_quiz_run_question_id", unique: true
  end

  create_table "balance_sheet_items", force: :cascade do |t|
    t.bigint "balance_sheet_id", null: false
    t.bigint "account_id", null: false
    t.bigint "amount", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_balance_sheet_items_on_account_id"
    t.index ["balance_sheet_id", "account_id"], name: "index_balance_sheet_items_on_balance_sheet_id_and_account_id", unique: true
    t.index ["balance_sheet_id"], name: "index_balance_sheet_items_on_balance_sheet_id"
    t.check_constraint "amount >= 0", name: "nonnegative_amount"
  end

  create_table "balance_sheets", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.integer "position", null: false
    t.string "company_name", null: false
    t.text "business_description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id", "position"], name: "index_balance_sheets_on_question_id_and_position", unique: true
    t.index ["question_id"], name: "index_balance_sheets_on_question_id"
    t.check_constraint "\"position\" = ANY (ARRAY[1, 2])", name: "valid_sheet_position"
  end

  create_table "choices", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.integer "position", null: false
    t.text "body", null: false
    t.boolean "is_correct", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id", "position"], name: "index_choices_on_question_id_and_position", unique: true
    t.index ["question_id"], name: "index_choices_on_question_id"
    t.check_constraint "\"position\" >= 1 AND \"position\" <= 3", name: "valid_choice_position"
  end

  create_table "industries", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_industries_on_name", unique: true
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "industry_id", null: false
    t.string "code", null: false
    t.integer "version", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.text "assumptions", null: false
    t.text "explanation", null: false
    t.datetime "published_at"
    t.datetime "retired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code", "version"], name: "index_questions_on_code_and_version", unique: true
    t.index ["code"], name: "one_active_question_version", unique: true, where: "((published_at IS NOT NULL) AND (retired_at IS NULL))"
    t.index ["industry_id"], name: "index_questions_on_industry_id"
    t.check_constraint "kind::text = ANY (ARRAY['company_comparison'::character varying, 'transaction'::character varying]::text[])", name: "valid_question_kind"
    t.check_constraint "retired_at IS NULL OR published_at IS NOT NULL AND retired_at >= published_at", name: "valid_retirement"
    t.check_constraint "version > 0", name: "positive_question_version"
  end

  create_table "quiz_run_questions", force: :cascade do |t|
    t.bigint "quiz_run_id", null: false
    t.bigint "question_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_quiz_run_questions_on_question_id"
    t.index ["quiz_run_id", "position"], name: "index_quiz_run_questions_on_quiz_run_id_and_position", unique: true
    t.index ["quiz_run_id", "question_id"], name: "index_quiz_run_questions_on_quiz_run_id_and_question_id", unique: true
    t.index ["quiz_run_id"], name: "index_quiz_run_questions_on_quiz_run_id"
    t.check_constraint "\"position\" >= 1 AND \"position\" <= 5", name: "valid_run_position"
  end

  create_table "quiz_runs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "industry_id"
    t.string "kind", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["industry_id"], name: "index_quiz_runs_on_industry_id"
    t.index ["user_id"], name: "index_quiz_runs_on_user_id"
    t.check_constraint "kind::text = ANY (ARRAY['quiz'::character varying, 'review'::character varying]::text[])", name: "valid_run_kind"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "email::text = lower(btrim(email::text))", name: "users_normalized_email"
  end

  add_foreign_key "answers", "choices"
  add_foreign_key "answers", "quiz_run_questions"
  add_foreign_key "balance_sheet_items", "accounts"
  add_foreign_key "balance_sheet_items", "balance_sheets"
  add_foreign_key "balance_sheets", "questions"
  add_foreign_key "choices", "questions"
  add_foreign_key "questions", "industries"
  add_foreign_key "quiz_run_questions", "questions"
  add_foreign_key "quiz_run_questions", "quiz_runs"
  add_foreign_key "quiz_runs", "industries"
  add_foreign_key "quiz_runs", "users"
end
