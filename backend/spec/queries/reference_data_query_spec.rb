require "rails_helper"

# Unit spec for ReferenceDataQuery (docs/api-contracts.md §6, DR-14).
# The request spec covers the HTTP contract; this spec covers the query object's own behaviour:
# ordering, constant pass-through, and the has_rate date-boundary rule.
RSpec.describe ReferenceDataQuery do
  before { create_currencies_and_rates }

  def query(on: Date.new(2024, 6, 1))
    described_class.call(on: on)
  end

  it "passes the reporting currency constant through unchanged" do
    expect(query[:reporting_currency]).to eq("USD")
  end

  it "passes the model job_level constants through unchanged" do
    expect(query[:job_levels]).to eq(Employee::JOB_LEVELS)
  end

  it "passes the salary pay_frequency constants through unchanged" do
    expect(query[:pay_frequencies]).to eq(SalaryRecord::PAY_FREQUENCIES)
  end

  it "passes the low_sample_threshold constant through unchanged" do
    expect(query[:low_sample_threshold]).to eq(Analytics::Summary::LOW_SAMPLE_THRESHOLD)
  end

  it "passes all three employment status values through unchanged" do
    expect(query[:employment_statuses]).to eq(Employee.employment_statuses.keys)
  end

  describe "countries" do
    it "returns every country ordered by name" do
      create_country("US", "United States")
      create_country("IN", "India")
      create_country("DE", "Germany")

      names = query[:countries].pluck(:name)
      expect(names).to eq([ "Germany", "India", "United States" ])
    end

    it "returns code and name for each country" do
      create_country("IN", "India")

      country = query[:countries].find { |c| c[:code] == "IN" }
      expect(country).to eq({ code: "IN", name: "India" })
    end
  end

  describe "departments" do
    it "returns every department ordered by name" do
      create_department("Sales")
      create_department("Engineering")
      create_department("Design")

      names = query[:departments].pluck(:name)
      expect(names).to eq(%w[Design Engineering Sales])
    end

    it "returns id and name for each department" do
      dept = create_department("Engineering")

      result = query[:departments].find { |d| d[:name] == "Engineering" }
      expect(result).to eq({ id: dept.id, name: "Engineering" })
    end
  end

  describe "currencies — has_rate flag" do
    # The four seeded currencies all have a rate from RATE_FLOOR (2020-01-01).

    it "marks every seeded currency has_rate: true when queried on or after the floor date" do
      codes = query[:currencies].to_h { |c| [ c[:code], c[:has_rate] ] }
      expect(codes).to eq("EUR" => true, "GBP" => true, "INR" => true, "USD" => true)
    end

    it "marks a currency has_rate: false when queried before the rate's effective_on" do
      # All four seeded rates are effective from 2020-01-01; querying on 2019-12-31 must yield false.
      codes = query(on: Date.new(2019, 12, 31))[:currencies].to_h { |c| [ c[:code], c[:has_rate] ] }
      expect(codes.values).to all(be(false))
    end

    it "marks a currency has_rate: false when it has no exchange rate at all" do
      Currency.create!(code: "JPY", name: "Japanese Yen") # no rate row

      result = query[:currencies].find { |c| c[:code] == "JPY" }
      expect(result[:has_rate]).to be(false)
    end

    it "does not count a rate whose effective_on is strictly after the query date" do
      ExchangeRate.create!(from_currency: "GBP", to_currency: "USD", rate: "1.30",
                           effective_on: Date.new(2025, 1, 1))
      # Remove the floor-date rate so only the future one remains.
      ExchangeRate.where(from_currency: "GBP", effective_on: ReferenceFixtures::RATE_FLOOR).delete_all

      result = query(on: Date.new(2024, 12, 31))[:currencies].find { |c| c[:code] == "GBP" }
      expect(result[:has_rate]).to be(false)
    end

    it "counts a rate whose effective_on equals the query date (inclusive boundary)" do
      ExchangeRate.create!(from_currency: "GBP", to_currency: "USD", rate: "1.30",
                           effective_on: Date.new(2025, 1, 1))
      ExchangeRate.where(from_currency: "GBP", effective_on: ReferenceFixtures::RATE_FLOOR).delete_all

      result = query(on: Date.new(2025, 1, 1))[:currencies].find { |c| c[:code] == "GBP" }
      expect(result[:has_rate]).to be(true)
    end

    it "returns currencies ordered by code" do
      Currency.create!(code: "JPY", name: "Japanese Yen")

      codes = query[:currencies].pluck(:code)
      expect(codes).to eq(%w[EUR GBP INR JPY USD])
    end

    it "returns code, name and has_rate for each currency" do
      result = query[:currencies].find { |c| c[:code] == "USD" }
      expect(result.keys).to contain_exactly(:code, :name, :has_rate)
    end
  end
end
