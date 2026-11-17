require "rails_helper"

RSpec.describe "GET /api/v1/analytics/summary", type: :request do
  before { create_demo_population }

  def data
    json["data"]
  end

  describe "organization totals (hand-computed from spec/support/demo_population.rb)" do
    it "counts only active employees, in USD, with exact decimals" do
      get "/api/v1/analytics/summary"

      expect(response).to have_http_status(:ok)
      expect(data["reporting_currency"]).to eq("USD")
      expect(data["filters"]).to eq("country" => nil, "department" => nil, "job_level" => nil)
      # active: 36,000.00 + 90,000.00 + 43,199.96 + 17,280.00
      expect(data["organization"]).to include(
        "active_headcount" => 4, "low_sample" => true,
        "total_annual_base_reporting" => "186479.96",
        "average_annual_base_reporting" => "46619.99",   # 186,479.96 / 4
        "median_annual_base_reporting" => "39599.98"     # (36,000.00 + 43,199.96) / 2
      )
      expect(data["notes"]).to eq([ "Averages and medians are comparisons only, not pay-equity conclusions.",
                                    "Reporting-currency values use fixed illustrative exchange rates." ])
    end

    it "reports status counts for every status, including employees excluded from payroll totals" do
      get "/api/v1/analytics/summary"

      expect(data["organization"]["status_counts"]).to eq("active" => 4, "on_leave" => 1, "terminated" => 1)
      expect(data["organization"]["status_counts"]["active"]).to eq(data["organization"]["active_headcount"])
      expect(data["organization"]["status_counts"].values.sum).to eq(Employee.count)
    end
  end

  describe "by country" do
    it "groups active employees, sorted by total descending, with same-currency local totals" do
      get "/api/v1/analytics/summary"

      expect(data["by_country"].map { |row| row["country"]["code"] }).to eq(%w[US IN DE])
      us, india, germany = data["by_country"]
      expect(us).to include("active_headcount" => 1, "total_annual_base_reporting" => "90000.00",
                            "average_annual_base_reporting" => "90000.00", "median_annual_base_reporting" => "90000.00",
                            "low_sample" => true)
      expect(india).to include("active_headcount" => 2, "total_annual_base_reporting" => "53280.00",
                               "average_annual_base_reporting" => "26640.00", "median_annual_base_reporting" => "26640.00")
      expect(india["local_totals"]).to eq([ { "currency" => "INR", "active_headcount" => 2, "total_annual_base_local" => "4440000.00" } ])
      expect(germany["local_totals"]).to eq([ { "currency" => "EUR", "active_headcount" => 1, "total_annual_base_local" => "39999.96" } ])
    end

    it "never adds raw amounts of different currencies" do
      us = Country.find("US")
      inr_in_us = Employee.create!(employee_number: "ACME-00007", first_name: "Hari", last_name: "Mehta", job_title: "X", job_level: 3,
                                   department: Department.first, country: us, employment_status: "active", hired_on: "2020-01-01")
      inr_in_us.salary_records.create!(amount: "250000.00", currency_code: "INR", pay_frequency: "monthly", fx_rate: "0.012",
                                       effective_from: Time.utc(2024, 1, 1), reason: "Initial salary")

      get "/api/v1/analytics/summary", params: { country: "US" }

      row = data["by_country"].first
      expect(row["total_annual_base_reporting"]).to eq("126000.00") # 90,000 USD + 36,000 USD converted
      expect(row["local_totals"]).to contain_exactly(
        { "currency" => "INR", "active_headcount" => 1, "total_annual_base_local" => "3000000.00" },
        { "currency" => "USD", "active_headcount" => 1, "total_annual_base_local" => "90000.00" }
      )
    end
  end

  describe "by department" do
    it "has no local totals and groups only active employees" do
      get "/api/v1/analytics/summary"

      expect(data["by_department"].map { |row| row["department"]["name"] }).to eq(%w[Engineering Sales])
      engineering, sales = data["by_department"]
      expect(engineering).to include("active_headcount" => 3, "total_annual_base_reporting" => "143280.00",
                                     "average_annual_base_reporting" => "47760.00", "median_annual_base_reporting" => "36000.00")
      expect(sales).to include("active_headcount" => 1, "total_annual_base_reporting" => "43199.96")
      expect(engineering).not_to have_key("local_totals")
    end
  end

  describe "filters" do
    it "narrows the whole summary, including status counts, to the filtered population" do
      get "/api/v1/analytics/summary", params: { country: "IN" }

      expect(data["filters"]).to eq("country" => "IN", "department" => nil, "job_level" => nil)
      expect(data["organization"]).to include("active_headcount" => 2, "total_annual_base_reporting" => "53280.00")
      expect(data["organization"]["status_counts"]).to eq("active" => 2, "on_leave" => 1, "terminated" => 0)
      expect(data["by_country"].map { |row| row["country"]["code"] }).to eq([ "IN" ])
    end

    it "filters by department and job level" do
      get "/api/v1/analytics/summary", params: { department: Department.find_by!(name: "Sales").id, job_level: 5 }

      expect(data["organization"]["active_headcount"]).to eq(1)
      expect(data["organization"]["total_annual_base_reporting"]).to eq("43199.96")
    end

    {
      "unknown country" => { country: "ZZ" }, "unknown department" => { department: "999999" },
      "job_level 0" => { job_level: "0" }, "job_level 8" => { job_level: "8" }, "job_level abc" => { job_level: "abc" }
    }.each do |label, params|
      it "rejects #{label} with 400 invalid_parameter" do
        get "/api/v1/analytics/summary", params: params

        expect(response).to have_http_status(:bad_request)
        expect(json["error"]["code"]).to eq("invalid_parameter")
      end
    end
  end

  describe "empty result contract" do
    it "returns zero headcount, 0.00 total and null average and median, omitting empty groups" do
      get "/api/v1/analytics/summary", params: { country: "DE", job_level: 1 }

      expect(data["organization"]).to include("active_headcount" => 0, "total_annual_base_reporting" => "0.00",
                                              "average_annual_base_reporting" => nil, "median_annual_base_reporting" => nil)
      expect(data["organization"]["status_counts"]).to eq("active" => 0, "on_leave" => 0, "terminated" => 0)
      expect(data["by_country"]).to eq([])
      expect(data["by_department"]).to eq([])
    end

    it "never emits NaN or Infinity" do
      get "/api/v1/analytics/summary", params: { country: "DE", job_level: 1 }

      expect(response.body).not_to match(/NaN|Infinity/)
    end
  end

  describe "exact numeric median (docs/domain-decisions.md §10.3)" do
    # Each case is one country whose active employees earn the given annual USD amounts.
    MEDIAN_CASES = {
      "odd" => [ %w[30000.00 45000.00 52000.00 61000.00 90000.00], "52000.00" ],
      "even" => [ %w[40000.00 50000.00 60000.00 80000.00], "55000.00" ],
      "even with a half cent" => [ %w[50000.00 50000.01], "50000.01" ],
      "even with duplicates" => [ %w[60000.00 60000.00 70000.00 70000.00], "65000.00" ],
      "single row" => [ %w[75000.00], "75000.00" ],
      "large magnitude (float regression)" => [ %w[123456789012.34 123456789012.35], "123456789012.35" ]
    }.freeze

    before do
      SalaryRecord.delete_all
      Employee.delete_all
    end

    def create_group(country_code, amounts)
      country = create_country(country_code, "Country #{country_code}")
      department = create_department("Dept #{country_code}")
      usd = Currency.find("USD")
      amounts.each_with_index do |amount, index|
        employee = Employee.create!(employee_number: "ACME-#{country_code}#{index}", first_name: "F", last_name: "L", job_title: "T",
                                    job_level: 3, department: department, country: country, employment_status: "active", hired_on: "2020-01-01")
        # insert_all! skips the application's DR-11 maximum so the numeric(14,2) magnitude case can be tested.
        SalaryRecord.insert_all!([ { employee_id: employee.id, amount: amount, currency_code: usd.code, pay_frequency: "annual",
                                     fx_rate: "1.0", effective_from: Time.utc(2024, 1, 1), reason: "test" } ])
      end
    end

    MEDIAN_CASES.each do |label, (amounts, expected)|
      it "gives #{expected} for #{label}, at organization, country and department level" do
        create_group("QA", amounts)

        get "/api/v1/analytics/summary"

        expect(data["organization"]["median_annual_base_reporting"]).to eq(expected)
        expect(data["by_country"].first["median_annual_base_reporting"]).to eq(expected)
        expect(data["by_department"].first["median_annual_base_reporting"]).to eq(expected)
      end
    end

    it "computes each group's median independently" do
      create_group("QA", %w[40000.00 50000.00 60000.00 80000.00])
      create_group("QB", %w[75000.00])

      get "/api/v1/analytics/summary"

      medians = data["by_country"].to_h { |row| [ row["country"]["code"], row["median_annual_base_reporting"] ] }
      expect(medians).to eq("QA" => "55000.00", "QB" => "75000.00")
      expect(data["organization"]["median_annual_base_reporting"]).to eq("60000.00") # 5 values: middle is 60,000
    end

    it "does not use percentile_cont or any floating-point type in its SQL" do
      create_group("QA", %w[50000.00 50000.01])
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload[:sql] }

      get "/api/v1/analytics/summary"
      ActiveSupport::Notifications.unsubscribe(subscriber)

      analytic_sql = statements.select { |sql| sql.include?("ranked") }
      expect(analytic_sql).not_to be_empty
      expect(analytic_sql.join).not_to match(/percentile_cont|double precision|float|::real|::float/i)
    end
  end

  describe "low_sample (DR-08 recommended threshold of 10)" do
    it "is true below 10 active employees and false from 10" do
      employees = create_list(:employee, 8, department: Department.first)
      employees.each { |e| create(:salary_record, employee: e) }
      get "/api/v1/analytics/summary", params: { country: "IN" }
      expect(data["by_country"].first).to include("active_headcount" => 10, "low_sample" => false)

      get "/api/v1/analytics/summary", params: { country: "DE" }
      expect(data["by_country"].first).to include("active_headcount" => 1, "low_sample" => true)
    end
  end

  it "aggregates in a fixed number of queries and never loads employees into Ruby" do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
    end
    get "/api/v1/analytics/summary"
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(queries.grep(/FROM "employees"\s*(WHERE|ORDER|LIMIT|\z)/).reject { |sql| sql.include?("GROUP BY") }).to be_empty
    expect(queries.size).to be <= 10
  end
end
