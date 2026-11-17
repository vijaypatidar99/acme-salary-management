require "rails_helper"

RSpec.describe Compensation do
  def reporting(amount, frequency, rate)
    described_class.annual_reporting(amount, frequency, rate)
  end

  describe ".annual_local" do
    it "multiplies a monthly amount by 12" do
      expect(described_class.annual_local("250000.00", "monthly")).to eq(BigDecimal("3000000.00"))
    end

    it "leaves an annual amount unchanged" do
      expect(described_class.annual_local("90000.00", "annual")).to eq(BigDecimal("90000.00"))
    end

    it "is exact at two decimals (no float error)" do
      expect(described_class.annual_local("3333.33", "monthly")).to eq(BigDecimal("39999.96"))
    end

    it "rejects an unknown pay frequency instead of guessing" do
      expect { described_class.annual_local("100.00", "weekly") }.to raise_error(KeyError)
    end
  end

  describe ".annual_reporting (docs/domain-decisions.md §4.2 worked examples)" do
    it "converts INR monthly: 250000.00 x 12 x 0.012 = 36000.00" do
      expect(reporting("250000.00", "monthly", "0.012")).to eq(BigDecimal("36000.00"))
    end

    it "rounds EUR monthly: 39999.96 x 1.08 = 43199.9568 -> 43199.96" do
      expect(reporting("3333.33", "monthly", "1.08")).to eq(BigDecimal("43199.96"))
    end

    it "annualizes before converting: GBP 4123.45 monthly -> 62841.38, not the convert-first 62841.36" do
      expect(reporting("4123.45", "monthly", "1.27")).to eq(BigDecimal("62841.38"))
      convert_first = (BigDecimal("4123.45") * BigDecimal("1.27")).round(2, :half_up) * 12
      expect(convert_first).to eq(BigDecimal("62841.36"))
    end

    it "keeps USD annual unchanged at rate 1" do
      expect(reporting("90000.00", "annual", "1")).to eq(BigDecimal("90000.00"))
    end

    it "rounds half away from zero at the boundary" do
      expect(reporting("0.05", "annual", "0.1")).to eq(BigDecimal("0.01")) # 0.005 -> 0.01
      expect(reporting("0.04", "annual", "0.1")).to eq(BigDecimal("0.00")) # 0.004 -> 0.00
    end

    it "uses only BigDecimal arithmetic" do
      expect(reporting("85000.00", "monthly", "0.012")).to be_a(BigDecimal)
    end

    it "keeps precision for very large amounts" do
      expect(reporting("999999999999.99", "annual", "1")).to eq(BigDecimal("999999999999.99"))
    end
  end

  describe "SQL parity" do
    PARITY_CASES = [
      [ "250000.00", "monthly", "0.012", "INR" ],
      [ "3333.33", "monthly", "1.08", "EUR" ],
      [ "4123.45", "monthly", "1.27", "GBP" ],
      [ "90000.00", "annual", "1.00000000", "USD" ],
      [ "0.05", "annual", "0.1", "USD" ],
      [ "999999999.99", "annual", "1.27", "GBP" ],
      [ "1000000000.00", "monthly", "0.01200000", "INR" ]
    ].freeze

    it "gives the same annual_local and annual_reporting in Ruby and in PostgreSQL for every case" do
      PARITY_CASES.each_with_index do |(amount, frequency, rate, code), i|
        employee = create(:employee, employee_number: "ACME-P#{i}")
        currency = Currency.find_or_create_by!(code: code) { |c| c.name = code }
        create(:salary_record, employee: employee, currency: currency, amount: amount, pay_frequency: frequency, fx_rate: rate)
      end

      rows = SalaryRecord.select(
        "salary_records.*",
        "#{described_class.annual_local_sql} AS sql_local",
        "#{described_class.annual_reporting_sql} AS sql_reporting"
      ).order(:id).to_a

      expect(rows.size).to eq(PARITY_CASES.size)
      rows.each do |row|
        expect(row.sql_local).to eq(row.annual_local)
        expect(row.sql_reporting).to eq(row.annual_reporting)
      end
    end
  end
end
