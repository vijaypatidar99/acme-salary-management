require "rails_helper"

RSpec.describe "GET /api/v1/employees", type: :request do
  before { create_demo_population }

  def numbers
    json["data"].map { |row| row["employee_number"] }
  end

  describe "response shape" do
    it "returns the contract fields, money as decimal strings, and pagination meta" do
      get "/api/v1/employees", params: { q: "ACME-00001" }

      expect(response).to have_http_status(:ok)
      expect(json["data"].first).to eq(
        "id" => Employee.find_by!(employee_number: "ACME-00001").id,
        "employee_number" => "ACME-00001", "first_name" => "Asha", "last_name" => "Rao",
        "job_title" => "Engineering Specialist", "job_level" => 4,
        "department" => { "id" => Department.find_by!(name: "Engineering").id, "name" => "Engineering" },
        "country" => { "code" => "IN", "name" => "India" },
        "employment_status" => "active", "hired_on" => "2019-04-01",
        "current_salary" => {
          "id" => SalaryRecord.joins(:employee).find_by!(employees: { employee_number: "ACME-00001" }).id,
          "amount" => "250000.00", "currency" => "INR", "pay_frequency" => "monthly",
          "annual_base_local" => "3000000.00", "annual_base_reporting" => "36000.00",
          "effective_from" => "2024-01-01T09:00:00.000000Z"
        }
      )
      expect(json["meta"]).to eq("page" => 1, "per_page" => 25, "total_count" => 1, "total_pages" => 1, "reporting_currency" => "USD")
    end

    it "never emits a JSON number for money" do
      get "/api/v1/employees"

      json["data"].each do |row|
        salary = row["current_salary"]
        %w[amount annual_base_local annual_base_reporting].each { |field| expect(salary[field]).to be_a(String) }
      end
    end

    it "converts EUR monthly with the annualize-first rule" do
      get "/api/v1/employees", params: { q: "Clara" }

      expect(json["data"].first["current_salary"].slice("annual_base_local", "annual_base_reporting"))
        .to eq("annual_base_local" => "39999.96", "annual_base_reporting" => "43199.96")
    end
  end

  describe "search" do
    it "matches first name, last name, full name and employee number, case-insensitively" do
      get "/api/v1/employees", params: { q: "asha" }
      expect(numbers).to eq(%w[ACME-00001])

      get "/api/v1/employees", params: { q: "RAO" }
      expect(numbers).to eq(%w[ACME-00001 ACME-00006])

      get "/api/v1/employees", params: { q: "ben carter" }
      expect(numbers).to eq(%w[ACME-00002])

      get "/api/v1/employees", params: { q: "acme-00004" }
      expect(numbers).to eq(%w[ACME-00004])
    end

    it "treats % and _ as literal characters, not wildcards" do
      create(:employee, employee_number: "ACME-09001", first_name: "50%_Off", last_name: "Literal")
      create(:employee, employee_number: "ACME-09002", first_name: "50xyOff", last_name: "Wildcard")

      get "/api/v1/employees", params: { q: "50%_" }

      expect(numbers).to eq(%w[ACME-09001])
    end

    it "treats a backslash literally and survives SQL metacharacters" do
      create(:employee, employee_number: "ACME-09003", first_name: "Back\\slash", last_name: "Case")

      get "/api/v1/employees", params: { q: "k\\s" }
      expect(numbers).to eq(%w[ACME-09003])

      get "/api/v1/employees", params: { q: "'; DROP TABLE employees; --" }
      expect(response).to have_http_status(:ok)
      expect(json["data"]).to be_empty
      expect(Employee.count).to be > 5
    end
  end

  describe "filters" do
    it "filters by country, department and status, and combines them" do
      get "/api/v1/employees", params: { country: "IN" }
      expect(numbers).to eq(%w[ACME-00001 ACME-00004 ACME-00006])

      get "/api/v1/employees", params: { department: Department.find_by!(name: "Sales").id }
      expect(numbers).to eq(%w[ACME-00003 ACME-00004 ACME-00005])

      get "/api/v1/employees", params: { status: "on_leave" }
      expect(numbers).to eq(%w[ACME-00004])

      get "/api/v1/employees", params: { country: "IN", status: "active", q: "rao" }
      expect(numbers).to eq(%w[ACME-00001 ACME-00006])
    end
  end

  describe "sorting" do
    it "sorts by employee_number ascending by default" do
      get "/api/v1/employees"
      expect(numbers).to eq(%w[ACME-00001 ACME-00002 ACME-00003 ACME-00004 ACME-00005 ACME-00006])
    end

    it "sorts by name (last, then first name)" do
      get "/api/v1/employees", params: { sort: "name" }
      expect(json["data"].map { |r| r["last_name"] }).to eq(%w[Brown Carter Patel Rao Rao Weiss])
    end

    it "uses the employee id as a stable tie-breaker" do
      get "/api/v1/employees", params: { sort: "name" }
      raos = json["data"].select { |row| row["last_name"] == "Rao" }.map { |row| row["employee_number"] }

      expect(raos).to eq(%w[ACME-00001 ACME-00006]) # Asha before Gita (first name), then id
    end

    it "sorts by annual USD salary, descending, with the id tie-breaker" do
      get "/api/v1/employees", params: { sort: "annual_base_reporting", direction: "desc" }

      expect(numbers).to eq(%w[ACME-00002 ACME-00005 ACME-00003 ACME-00001 ACME-00006 ACME-00004])
    end

    it "sorts USD amounts across currencies, not raw local amounts" do
      get "/api/v1/employees", params: { sort: "annual_base_reporting", direction: "asc" }

      expect(numbers.first).to eq("ACME-00004") # 14,400 USD although its local amount is the largest
    end

    %w[country department job_level hired_on status].each do |sort|
      it "accepts sort=#{sort}" do
        get "/api/v1/employees", params: { sort: sort, direction: "desc" }
        expect(response).to have_http_status(:ok)
        expect(json["data"].size).to eq(6)
      end
    end
  end

  describe "pagination" do
    it "pages through the result with correct meta" do
      get "/api/v1/employees", params: { per_page: 4, page: 2 }

      expect(numbers).to eq(%w[ACME-00005 ACME-00006])
      expect(json["meta"]).to include("page" => 2, "per_page" => 4, "total_count" => 6, "total_pages" => 2)
    end

    it "returns 200 with empty data for a page beyond the last, keeping real totals" do
      get "/api/v1/employees", params: { per_page: 4, page: 99 }

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to eq([])
      expect(json["meta"]).to include("total_count" => 6, "total_pages" => 2)
    end

    it "survives an enormous page number" do
      get "/api/v1/employees", params: { page: "99999999999999999999999" }

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to eq([])
    end

    it "reports total_pages 0 for an empty result" do
      get "/api/v1/employees", params: { q: "nobody-matches-this" }

      expect(json["data"]).to eq([])
      expect(json["meta"]).to include("total_count" => 0, "total_pages" => 0, "page" => 1)
    end

    it "does not repeat or skip rows across pages when sort keys tie" do
      collected = (1..3).flat_map do |page|
        get "/api/v1/employees", params: { sort: "job_level", per_page: 2, page: page }
        numbers
      end

      expect(collected).to match_array(Employee.pluck(:employee_number))
      expect(collected.uniq.size).to eq(6)
    end
  end

  describe "parameter validation (400 invalid_parameter)" do
    {
      "page=0" => { page: "0" }, "page=-1" => { page: "-1" }, "page=abc" => { page: "abc" }, "page=1.5" => { page: "1.5" },
      "per_page=0" => { per_page: "0" }, "per_page=101" => { per_page: "101" }, "per_page=x" => { per_page: "x" },
      "unknown sort" => { sort: "salary; DROP TABLE employees" }, "bad direction" => { direction: "sideways" },
      "bad status" => { status: "retired" }, "unknown country" => { country: "ZZ" }, "lowercase country" => { country: "in" },
      "unknown department" => { department: "999999" }, "non-numeric department" => { department: "eng" },
      "q too long" => { q: "a" * 101 }
    }.each do |label, params|
      it "rejects #{label}" do
        get "/api/v1/employees", params: params

        expect(response).to have_http_status(:bad_request)
        expect(json["error"]["code"]).to eq("invalid_parameter")
        expect(json["error"]["details"]).to be_a(Hash)
      end
    end

    it "rejects an array-valued parameter" do
      get "/api/v1/employees?q[]=a"

      expect(response).to have_http_status(:bad_request)
    end

    it "accepts per_page 1 and 100" do
      get "/api/v1/employees", params: { per_page: 1 }
      expect(json["data"].size).to eq(1)
      get "/api/v1/employees", params: { per_page: 100 }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "query count" do
    it "uses a fixed number of queries regardless of page size" do
      count_queries = lambda do |per_page|
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
        end
        get "/api/v1/employees", params: { per_page: per_page }
        ActiveSupport::Notifications.unsubscribe(subscriber)
        queries.size
      end

      count_queries.call(2) # warm up
      expect(count_queries.call(2)).to eq(count_queries.call(6))
      expect(count_queries.call(6)).to be <= 3 # validation lookups + count + page
    end
  end
end

RSpec.describe "GET /api/v1/employees/:id", type: :request do
  before { create_demo_population }

  let(:employee) { Employee.find_by!(employee_number: "ACME-00001") }

  it "returns the employee with current salary and complete history, newest first" do
    old = employee.salary_records.current.first
    old.update!(effective_to: Time.utc(2025, 4, 1))
    employee.salary_records.create!(amount: "270000.00", currency_code: "INR", pay_frequency: "monthly", fx_rate: "0.013",
                                    effective_from: Time.utc(2025, 4, 1), reason: "Annual review")

    get "/api/v1/employees/#{employee.id}"

    expect(response).to have_http_status(:ok)
    data = json["data"]
    expect(data).to include("employee_number" => "ACME-00001", "terminated_on" => nil, "can_revise_salary" => true,
                            "reporting_currency" => "USD", "hired_on" => "2019-04-01")
    expect(data["department"]).to eq("id" => employee.department_id, "name" => "Engineering")
    expect(data["country"]).to eq("code" => "IN", "name" => "India")
    expect(data["salary_history"].map { |r| r["is_current"] }).to eq([ true, false ])
    expect(data["current_salary"]).to eq(data["salary_history"].first)
    expect(data["current_salary"]).to include("amount" => "270000.00", "fx_rate" => "0.01300000",
                                              "annual_base_local" => "3240000.00", "annual_base_reporting" => "42120.00",
                                              "effective_to" => nil, "reason" => "Annual review")
    previous = data["salary_history"].last
    expect(previous).to include("amount" => "250000.00", "fx_rate" => "0.01200000", "annual_base_reporting" => "36000.00",
                                "effective_from" => "2024-01-01T09:00:00.000000Z", "effective_to" => "2025-04-01T00:00:00.000000Z")
  end

  it "says whether a salary revision is allowed, by employment status (DR-03)" do
    [ [ "ACME-00001", true ], [ "ACME-00004", true ], [ "ACME-00005", false ] ].each do |number, allowed|
      get "/api/v1/employees/#{Employee.find_by!(employee_number: number).id}"

      expect(json["data"]["can_revise_salary"]).to be(allowed), "#{number} can_revise_salary"
    end
    expect(json["data"]["terminated_on"]).to eq("2024-01-01")
  end

  it "uses a fixed number of queries however long the history is" do
    count_queries = lambda do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
      end
      get "/api/v1/employees/#{employee.id}"
      ActiveSupport::Notifications.unsubscribe(subscriber)
      queries.size
    end
    count_queries.call # warm up (first request in a process loads type maps)
    short = count_queries.call
    employee.salary_records.current.first.update!(effective_to: Time.utc(2025, 1, 1))
    employee.salary_records.create!(amount: "1.00", currency_code: "USD", pay_frequency: "annual", fx_rate: "1", effective_from: Time.utc(2025, 1, 1), reason: "x")

    expect(count_queries.call).to eq(short)
    expect(short).to be <= 4
  end

  it "returns the documented 404 for a missing or malformed id" do
    get "/api/v1/employees/0"
    expect(response).to have_http_status(:not_found)
    expect(json).to eq("error" => { "code" => "not_found", "message" => "Not found" })

    get "/api/v1/employees/not-a-number"
    expect(response).to have_http_status(:not_found)
  end
end
