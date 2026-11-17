require "rails_helper"

# Each example bypasses model validations (insert_all!) so the DATABASE itself is what rejects the row.
RSpec.describe "Database constraints" do
  let(:usd) { Currency.find_or_create_by!(code: "USD") { |c| c.name = "US Dollar" } }
  let!(:employee) { create(:employee) }
  let(:conn) { ActiveRecord::Base.connection }

  # Runs the block in a savepoint so one rejected statement does not abort the example's transaction.
  def expect_db_error(error_class, &block)
    expect { ActiveRecord::Base.transaction(requires_new: true, &block) }.to raise_error(error_class)
  end

  def salary_row(employee_id:, from:, to: nil, **overrides)
    { employee_id: employee_id, amount: "1000.00", currency_code: "USD", pay_frequency: "annual", fx_rate: "1.0",
      effective_from: from, effective_to: to, reason: "test" }.merge(overrides)
  end

  def insert_salary(**row)
    SalaryRecord.insert_all!([ salary_row(**row) ])
  end

  def employee_row(**overrides)
    { employee_number: "ACME-X#{rand(1_000_000)}", first_name: "A", last_name: "B", job_title: "T", job_level: 3,
      department_id: employee.department_id, country_code: "IN", employment_status: "active", hired_on: "2020-01-01" }.merge(overrides)
  end

  before { usd }

  describe "salary_records: interval integrity (DR-20)" do
    it "accepts adjacent half-open intervals" do
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), to: Time.utc(2025, 6, 1))
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 6, 1), to: Time.utc(2025, 9, 1))
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 9, 1))

      expect(SalaryRecord.where(employee_id: employee.id).count).to eq(3)
    end

    it "rejects a second open-ended record" do
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1))

      expect_db_error(ActiveRecord::StatementInvalid) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 6, 1)) }
    end

    it "rejects overlapping closed intervals, which the partial unique index alone would allow" do
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), to: Time.utc(2025, 6, 1))

      expect_db_error(ActiveRecord::ExclusionViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 3, 1), to: Time.utc(2025, 9, 1)) }
    end

    it "rejects an interval nested inside another and one that starts earlier and overlaps the start" do
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), to: Time.utc(2025, 12, 1))

      expect_db_error(ActiveRecord::ExclusionViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 3, 1), to: Time.utc(2025, 4, 1)) }
      expect_db_error(ActiveRecord::ExclusionViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2024, 6, 1), to: Time.utc(2025, 2, 1)) }
    end

    it "allows the same period for different employees" do
      other = create(:employee)
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), to: Time.utc(2025, 6, 1))

      expect { insert_salary(employee_id: other.id, from: Time.utc(2025, 1, 1), to: Time.utc(2025, 6, 1)) }.not_to raise_error
    end

    it "proves the partial unique index does not stop a historical overlap on its own" do
      ActiveRecord::Base.transaction do
        conn.execute("ALTER TABLE salary_records DROP CONSTRAINT salary_records_no_overlap")
        insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), to: Time.utc(2025, 6, 1))

        expect { insert_salary(employee_id: employee.id, from: Time.utc(2025, 3, 1), to: Time.utc(2025, 9, 1)) }.not_to raise_error
        raise ActiveRecord::Rollback
      end
      expect(conn.select_value("SELECT count(*) FROM pg_constraint WHERE conname = 'salary_records_no_overlap'")).to eq(1)
    end

    it "rejects effective_to equal to or earlier than effective_from" do
      expect_db_error(ActiveRecord::CheckViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 6, 1), to: Time.utc(2025, 6, 1)) }
      expect_db_error(ActiveRecord::CheckViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 6, 1), to: Time.utc(2025, 5, 1)) }
    end

    it "stores timestamps with microsecond precision" do
      at = Time.utc(2025, 1, 1, 9, 30, 0, 123_456)
      insert_salary(employee_id: employee.id, from: at)

      expect(SalaryRecord.find_by(employee_id: employee.id).effective_from).to eq(at)
    end
  end

  describe "salary_records: values" do
    it "rejects NaN amounts and FX snapshots even when validations are bypassed" do
      %i[amount fx_rate].each do |attribute|
        expect_db_error(ActiveRecord::CheckViolation) do
          insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), attribute => "NaN")
        end
      end
    end
    it "rejects zero and negative amounts, and a non-positive fx_rate" do
      expect_db_error(ActiveRecord::CheckViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), amount: "0") }
      expect_db_error(ActiveRecord::CheckViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), amount: "-5") }
      expect_db_error(ActiveRecord::CheckViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), fx_rate: "0") }
    end

    it "rejects an amount beyond the numeric(14,2) capacity but accepts the largest value it can hold" do
      expect_db_error(ActiveRecord::RangeError) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), amount: "1000000000000.00") }
      expect { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), amount: "999999999999.99") }.not_to raise_error
    end

    it "silently rounds a third decimal place (why the application must validate it first)" do
      insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), amount: "10.005")

      expect(SalaryRecord.find_by(employee_id: employee.id).amount).to eq(BigDecimal("10.01"))
    end

    it "rejects an unknown pay frequency" do
      expect_db_error(ActiveRecord::CheckViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), pay_frequency: "weekly") }
    end

    it "rejects a blank reason and a reason longer than 255 characters" do
      expect_db_error(ActiveRecord::CheckViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), reason: "   ") }
      expect_db_error(ActiveRecord::StatementInvalid) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), reason: "a" * 256) }
    end

    it "rejects missing required columns" do
      expect_db_error(ActiveRecord::NotNullViolation) { insert_salary(employee_id: employee.id, from: nil) }
      expect_db_error(ActiveRecord::NotNullViolation) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), fx_rate: nil) }
    end

    it "rejects an unknown currency and an unknown employee" do
      expect_db_error(ActiveRecord::InvalidForeignKey) { insert_salary(employee_id: employee.id, from: Time.utc(2025, 1, 1), currency_code: "XXX") }
      expect_db_error(ActiveRecord::InvalidForeignKey) { insert_salary(employee_id: 0, from: Time.utc(2025, 1, 1)) }
    end
  end

  describe "employees" do
    it "rejects a duplicate employee number" do
      Employee.insert_all!([ employee_row(employee_number: "ACME-DUP") ])

      expect_db_error(ActiveRecord::RecordNotUnique) { Employee.insert_all!([ employee_row(employee_number: "ACME-DUP") ]) }
    end

    it "rejects bad status values and job levels" do
      expect_db_error(ActiveRecord::CheckViolation) { Employee.insert_all!([ employee_row(employment_status: "retired") ]) }
      expect_db_error(ActiveRecord::CheckViolation) { Employee.insert_all!([ employee_row(job_level: 0) ]) }
      expect_db_error(ActiveRecord::CheckViolation) { Employee.insert_all!([ employee_row(job_level: 8) ]) }
    end

    it "enforces terminated_on if and only if terminated, and not before hiring" do
      expect_db_error(ActiveRecord::CheckViolation) { Employee.insert_all!([ employee_row(employment_status: "terminated") ]) }
      expect_db_error(ActiveRecord::CheckViolation) { Employee.insert_all!([ employee_row(terminated_on: "2024-01-01") ]) }
      expect_db_error(ActiveRecord::CheckViolation) { Employee.insert_all!([ employee_row(employment_status: "terminated", terminated_on: "2019-01-01") ]) }
      expect { Employee.insert_all!([ employee_row(employment_status: "terminated", terminated_on: "2024-01-01") ]) }.not_to raise_error
    end

    it "rejects an unknown department or country" do
      expect_db_error(ActiveRecord::InvalidForeignKey) { Employee.insert_all!([ employee_row(department_id: 0) ]) }
      expect_db_error(ActiveRecord::InvalidForeignKey) { Employee.insert_all!([ employee_row(country_code: "ZZ") ]) }
    end
  end

  describe "reference tables (DR-21: varchar codes with explicit CHECKs)" do
    it "enforces code length and uppercase format on countries and currencies" do
      expect_db_error(ActiveRecord::CheckViolation) { Country.insert_all!([ { code: "I", name: "x" } ]) }
      expect_db_error(ActiveRecord::CheckViolation) { Country.insert_all!([ { code: "in", name: "x" } ]) }
      expect_db_error(ActiveRecord::StatementInvalid) { Currency.insert_all!([ { code: "US", name: "x" } ]) }
      expect_db_error(ActiveRecord::CheckViolation) { Currency.insert_all!([ { code: "us1", name: "x" } ]) }
    end

    it "keeps unique country and department names" do
      Country.insert_all!([ { code: "QQ", name: "Qland" } ])
      expect_db_error(ActiveRecord::RecordNotUnique) { Country.insert_all!([ { code: "QR", name: "Qland" } ]) }
      Department.insert_all!([ { name: "Unique Dept" } ])
      expect_db_error(ActiveRecord::RecordNotUnique) { Department.insert_all!([ { name: "Unique Dept" } ]) }
    end
  end

  describe "exchange_rates" do
    it "rejects NaN reference rates even when validations are bypassed" do
      create(:currency, code: "EUR", name: "Euro")
      expect_db_error(ActiveRecord::CheckViolation) do
        ExchangeRate.insert_all!([ { from_currency: "EUR", to_currency: "USD", rate: "NaN",
                                     effective_on: "2020-01-01", created_at: Time.current } ])
      end
    end
    it "rejects non-positive rates, duplicate effective dates and unknown currencies" do
      create(:currency, code: "EUR", name: "Euro")
      row = { from_currency: "EUR", to_currency: "USD", rate: "1.08", effective_on: "2020-01-01", created_at: Time.current }
      ExchangeRate.insert_all!([ row ])

      expect_db_error(ActiveRecord::CheckViolation) { ExchangeRate.insert_all!([ row.merge(rate: "0", effective_on: "2021-01-01") ]) }
      expect_db_error(ActiveRecord::RecordNotUnique) { ExchangeRate.insert_all!([ row ]) }
      expect_db_error(ActiveRecord::InvalidForeignKey) { ExchangeRate.insert_all!([ row.merge(from_currency: "XXX", effective_on: "2022-01-01") ]) }
    end

    it "requires an identity rate of exactly 1" do
      expect_db_error(ActiveRecord::CheckViolation) { ExchangeRate.insert_all!([ { from_currency: "USD", to_currency: "USD", rate: "2", effective_on: "2020-01-01", created_at: Time.current } ]) }
      expect { ExchangeRate.insert_all!([ { from_currency: "USD", to_currency: "USD", rate: "1", effective_on: "2020-01-01", created_at: Time.current } ]) }
        .not_to raise_error
    end
  end
end
