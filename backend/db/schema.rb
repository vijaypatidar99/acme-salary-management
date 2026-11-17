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

ActiveRecord::Schema[8.1].define(version: 2026_11_17_120006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "countries", primary_key: "code", id: { type: :string, limit: 2 }, force: :cascade do |t|
    t.string "name", null: false
    t.index ["name"], name: "index_countries_on_name", unique: true
    t.check_constraint "char_length(code::text) = 2", name: "countries_code_length"
    t.check_constraint "code::text ~ '^[A-Z]+$'::text", name: "countries_code_format"
  end

  create_table "currencies", primary_key: "code", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.string "name", null: false
    t.check_constraint "char_length(code::text) = 3", name: "currencies_code_length"
    t.check_constraint "code::text ~ '^[A-Z]+$'::text", name: "currencies_code_format"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.index ["name"], name: "index_departments_on_name", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_number", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "job_title", null: false
    t.integer "job_level", limit: 2, null: false
    t.bigint "department_id", null: false
    t.string "country_code", limit: 2, null: false
    t.string "employment_status", null: false
    t.date "hired_on", null: false
    t.date "terminated_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code"], name: "index_employees_on_country_code"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
    t.check_constraint "(employment_status::text = 'terminated'::text) = (terminated_on IS NOT NULL) AND (terminated_on IS NULL OR terminated_on >= hired_on)", name: "employees_terminated_on_rule"
    t.check_constraint "employment_status::text = ANY (ARRAY['active'::character varying::text, 'on_leave'::character varying::text, 'terminated'::character varying::text])", name: "employees_status_values"
    t.check_constraint "job_level >= 1 AND job_level <= 7", name: "employees_job_level_range"
  end

  create_table "exchange_rates", force: :cascade do |t|
    t.string "from_currency", limit: 3, null: false
    t.string "to_currency", limit: 3, null: false
    t.decimal "rate", precision: 18, scale: 8, null: false
    t.date "effective_on", null: false
    t.datetime "created_at", null: false
    t.index ["from_currency", "to_currency", "effective_on"], name: "index_exchange_rates_lookup", unique: true
    t.check_constraint "from_currency::text <> to_currency::text OR rate = 1::numeric", name: "exchange_rates_identity_rate"
    t.check_constraint "rate > 0::numeric AND rate <> 'NaN'::numeric", name: "exchange_rates_rate_positive"
  end

  create_table "salary_records", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "currency_code", limit: 3, null: false
    t.string "pay_frequency", null: false
    t.decimal "fx_rate", precision: 18, scale: 8, null: false
    t.timestamptz "effective_from", null: false
    t.timestamptz "effective_to"
    t.string "reason", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_salary_records_one_open_per_employee", unique: true, where: "(effective_to IS NULL)"
    t.check_constraint "amount > 0::numeric AND amount <> 'NaN'::numeric", name: "salary_records_amount_positive"
    t.check_constraint "btrim(reason::text) <> ''::text", name: "salary_records_reason_present"
    t.check_constraint "effective_to IS NULL OR effective_to > effective_from", name: "salary_records_interval_ordered"
    t.check_constraint "fx_rate > 0::numeric AND fx_rate <> 'NaN'::numeric", name: "salary_records_fx_rate_positive"
    t.check_constraint "pay_frequency::text = ANY (ARRAY['monthly'::character varying::text, 'annual'::character varying::text])", name: "salary_records_pay_frequency_values"
    t.exclusion_constraint "employee_id WITH =, tstzrange(effective_from, effective_to, '[)'::text) WITH &&", using: :gist, name: "salary_records_no_overlap"
  end

  add_foreign_key "employees", "countries", column: "country_code", primary_key: "code", name: "fk_employees_country_code"
  add_foreign_key "employees", "departments"
  add_foreign_key "exchange_rates", "currencies", column: "from_currency", primary_key: "code", name: "fk_exchange_rates_from_currency"
  add_foreign_key "exchange_rates", "currencies", column: "to_currency", primary_key: "code", name: "fk_exchange_rates_to_currency"
  add_foreign_key "salary_records", "currencies", column: "currency_code", primary_key: "code", name: "fk_salary_records_currency_code"
  add_foreign_key "salary_records", "employees"
end
