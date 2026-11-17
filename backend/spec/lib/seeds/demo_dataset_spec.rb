require "rails_helper"

RSpec.describe Seeds::DemoDataset do
  SMALL = 300

  def seed(**options)
    described_class.call(employee_count: SMALL, **options)
  end

  describe "a small deterministic run" do
    it "creates exactly the requested number of employees with the documented coverage" do
      summary = seed

      expect(summary).to include(employees: SMALL, countries: 6, departments: 9, currencies: 4)
      expect(Employee.count).to eq(SMALL)
      expect(Employee.pluck(:employee_number).first).to eq("ACME-00001")
      expect(Employee.pluck(:employee_number).last).to eq(format("ACME-%05d", SMALL))
      expect(Employee.distinct.pluck(:employment_status)).to match_array(%w[active on_leave terminated])
      expect(Employee.distinct.pluck(:job_level).sort).to eq((1..7).to_a)
      expect(Employee.distinct.count(:country_code)).to be >= 4
      expect(Employee.distinct.count(:department_id)).to be >= 6
    end

    it "gives every employee exactly one open salary record and valid, contiguous, non-overlapping history" do
      seed

      expect(Employee.where.not(id: SalaryRecord.current.select(:employee_id))).to be_empty
      expect(SalaryRecord.current.group(:employee_id).having("count(*) > 1").count).to be_empty
      expect(SalaryRecord.where.not(effective_to: nil).count).to be > 0

      Employee.includes(:salary_records).find_each do |employee|
        records = employee.salary_records.sort_by(&:effective_from)
        records.each_cons(2) { |earlier, later| expect(earlier.effective_to).to eq(later.effective_from) }
        expect(records.first.effective_from.to_date).to be >= employee.hired_on
        expect(records.last).to be_current
        expect(records.first.reason).to eq("Initial salary")
        if employee.terminated_on
          expect(records.last.effective_from.to_date).to be < employee.terminated_on
          expect(employee.salary_records.current.count).to eq(1) # DR-09: the last salary stays open
        end
      end
    end

    it "snapshots the fx rate by the same lookup rule the revision service uses, and never uses a rate of 1 for a foreign currency" do
      seed

      SalaryRecord.find_each do |record|
        expect(record.fx_rate).to eq(ExchangeRate.lookup(record.currency_code, on: record.effective_from).rate)
      end
      expect(SalaryRecord.where(currency_code: "INR").distinct.pluck(:fx_rate)).to eq([ BigDecimal("0.012") ])
    end

    it "keeps every amount a valid positive decimal within the maximum, paid monthly or annually" do
      seed

      expect(SalaryRecord.pluck(:amount)).to all(be > 0).and all(be <= SalaryAmount::MAX)
      expect(SalaryRecord.distinct.pluck(:pay_frequency)).to match_array(%w[monthly annual])
      expect(SalaryRecord.distinct.pluck(:currency_code)).to match_array(%w[USD EUR GBP INR])
    end

    it "pays a minority in a currency other than the country's home currency" do
      seed

      home = Seeds::DemoDataset::COUNTRIES.transform_values { |v| v[1] }
      mismatched = SalaryRecord.current.joins(:employee).count { |record| home.fetch(record.employee.country_code) != record.currency_code }
      expect(mismatched).to be < SMALL / 4
    end

    it "uses no real data: names come only from the curated pools" do
      seed

      expect(Employee.distinct.pluck(:first_name) - Seeds::Names::FIRST).to be_empty
      expect(Employee.distinct.pluck(:last_name) - Seeds::Names::LAST).to be_empty
    end
  end

  describe "determinism" do
    it "produces identical data on two runs from an empty database" do
      first = seed[:fingerprint]
      second = seed(reset: true)[:fingerprint]

      expect(second).to eq(first)
    end

    it "changes the fingerprint when the employee count changes" do
      first = seed[:fingerprint]

      expect(described_class.call(employee_count: SMALL + 1, reset: true)[:fingerprint]).not_to eq(first)
    end
  end

  describe "re-running" do
    it "is a safe no-op when the same dataset is already present" do
      seed
      before = SalaryRecord.maximum(:id)

      summary = seed

      expect(summary[:already_seeded]).to be(true)
      expect(SalaryRecord.maximum(:id)).to eq(before)
      expect(Employee.count).to eq(SMALL)
    end

    it "refuses to touch a database holding other data unless reset is requested" do
      create(:salary_record)

      expect { seed }.to raise_error(described_class::Error, /RESET=1/)
      expect(Employee.count).to eq(1)

      seed(reset: true)
      expect(Employee.count).to eq(SMALL)
    end
  end

  describe "production safety" do
    around do |example|
      original = ENV["ALLOW_PRODUCTION_SEED"]
      example.run
    ensure
      original.nil? ? ENV.delete("ALLOW_PRODUCTION_SEED") : ENV["ALLOW_PRODUCTION_SEED"] = original
    end

    it "refuses to run in production without an explicit override" do
      allow(Rails.env).to receive(:production?).and_return(true)
      ENV.delete("ALLOW_PRODUCTION_SEED")

      expect { seed }.to raise_error(described_class::Error, /Refusing to seed demo data in production/)
      expect(Employee.count).to eq(0)
    end

    it "runs in production when ALLOW_PRODUCTION_SEED=1" do
      allow(Rails.env).to receive(:production?).and_return(true)
      ENV["ALLOW_PRODUCTION_SEED"] = "1"

      expect(seed[:employees]).to eq(SMALL)
    end
  end

  describe "post-seed verification" do
    before { seed }

    it "passes on a good dataset" do
      expect(described_class.new(employee_count: SMALL).verify!).to include(employees: SMALL)
    end

    it "fails loudly when an employee loses its open record" do
      SalaryRecord.where(id: SalaryRecord.current.limit(1).select(:id)).update_all(effective_to: Time.utc(2030, 1, 1))

      expect { described_class.new(employee_count: SMALL).verify! }.to raise_error(described_class::Error, /without exactly one open salary record/)
    end

    it "fails when the employee count is wrong" do
      expect { described_class.new(employee_count: SMALL + 1).verify! }.to raise_error(described_class::Error, /expected #{SMALL + 1} employees/)
    end

    it "fails when a salary record's fx_rate no longer matches the rate lookup" do
      SalaryRecord.where(id: SalaryRecord.first.id).update_all(fx_rate: "9.99")

      expect { described_class.new(employee_count: SMALL).verify! }.to raise_error(described_class::Error, /fx_rate differs/)
    end
  end

  describe "atomic verification" do
    it "rolls back generated data if post-seed verification fails" do
      allow_any_instance_of(described_class).to receive(:verify!).and_raise(described_class::Error, "verification failed")

      expect { seed }.to raise_error(described_class::Error, "verification failed")
      expect(Employee.count).to eq(0)
      expect(SalaryRecord.count).to eq(0)
      expect(Currency.count).to eq(0)
    end

    it "preserves the previous dataset if reset verification fails" do
      original = seed[:fingerprint]
      generator = described_class.new(employee_count: SMALL + 1, reset: true)
      allow(generator).to receive(:verify!).and_raise(described_class::Error, "verification failed")

      expect { generator.call }.to raise_error(described_class::Error)
      expect(described_class.new(employee_count: SMALL).fingerprint).to eq(original)
    end
  end

  describe "full size", :full_seed do
    it "creates exactly 10,000 employees, passes every invariant and has demonstrable low-sample groups" do
      summary = described_class.call

      expect(summary[:employees]).to eq(10_000)
      expect(Employee.count).to eq(10_000)
      expect(summary[:status_counts]).to eq("active" => 9200, "on_leave" => 300, "terminated" => 500)
      expect(Employee.where(country_code: "IE").count).to be < 10
      expect(Employee.where(department_id: Department.find_by!(name: "Legal").id, employment_status: "active").count).to be < 10
      expect(described_class.call[:already_seeded]).to be(true)
      expect(described_class.call(reset: true)[:fingerprint]).to eq(summary[:fingerprint])
    end
  end
end
