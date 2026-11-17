# Append-only salary history. Intervals are half-open: [effective_from, effective_to).
class CreateSalaryRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_records do |t|
      t.references :employee, null: false, foreign_key: true, index: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :currency_code, limit: 3, null: false
      t.string :pay_frequency, null: false
      t.decimal :fx_rate, precision: 18, scale: 8, null: false # DR-05: rate used, 1 unit of currency = fx_rate USD
      t.timestamptz :effective_from, precision: 6, null: false
      t.timestamptz :effective_to, precision: 6
      t.string :reason, limit: 255, null: false # DR-12
      t.timestamps

      # At most one open (current) record per employee, and the current-salary lookup used by every read.
      t.index :employee_id, unique: true, where: "effective_to IS NULL",
                            name: "index_salary_records_one_open_per_employee"
      t.check_constraint "amount > 0", name: "salary_records_amount_positive"
      t.check_constraint "fx_rate > 0", name: "salary_records_fx_rate_positive"
      t.check_constraint "pay_frequency IN ('monthly', 'annual')", name: "salary_records_pay_frequency_values"
      t.check_constraint "effective_to IS NULL OR effective_to > effective_from", name: "salary_records_interval_ordered"
      t.check_constraint "btrim(reason) <> ''", name: "salary_records_reason_present"
      # No two records of one employee may overlap, including historical ones (DR-20). Adjacent
      # half-open ranges are allowed. The partial unique index above does not prevent historical overlaps.
      t.exclusion_constraint "employee_id WITH =, tstzrange(effective_from, effective_to, '[)') WITH &&",
                             using: :gist, name: "salary_records_no_overlap"
    end

    add_foreign_key :salary_records, :currencies, column: :currency_code, primary_key: :code,
                                                  name: "fk_salary_records_currency_code"
  end
end
