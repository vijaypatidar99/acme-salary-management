require "rails_helper"

RSpec.describe "GET /api/v1/employees/export.csv", type: :request do
  before { create_demo_population }

  EXPORT_HEADER = %w[employee_number first_name last_name department country_code country job_title job_level employment_status
              hired_on terminated_on salary_amount salary_currency pay_frequency annual_base_local fx_rate_to_usd annual_base_usd
              salary_effective_from].freeze

  # A tiny RFC 4180 reader so the specs check what a spreadsheet would actually see.
  def parse_csv(body)
    rows = [ [] ]
    field = +""
    quoted = false
    chars = body.chars
    until chars.empty?
      char = chars.shift
      if quoted
        if char == "\"" && chars.first == "\"" then field << chars.shift
        elsif char == "\"" then quoted = false
        else field << char
        end
      elsif char == "\"" then quoted = true
      elsif char == "," then rows.last << field
                             field = +""
      elsif char == "\r" && chars.first == "\n" then chars.shift
                                                     rows.last << field
                                                     field = +""
                                                     rows << []
      else field << char
      end
    end
    rows.pop if rows.last.empty?
    rows
  end

  def export(params = {})
    get "/api/v1/employees/export.csv", params: params
    parse_csv(response.body)
  end

  it "returns a CSV attachment with the documented header and one row per employee" do
    rows = export

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Type"]).to eq("text/csv; charset=utf-8")
    expect(response.headers["Content-Disposition"]).to match(/\Aattachment; filename="employees-\d{8}\.csv"\z/)
    expect(rows.first).to eq(EXPORT_HEADER)
    expect(rows.size).to eq(7)
  end

  it "writes the documented values for a row (money as decimal strings, dates ISO 8601)" do
    row = export(q: "ACME-00001")[1]

    expect(EXPORT_HEADER.zip(row).to_h).to eq(
      "employee_number" => "ACME-00001", "first_name" => "Asha", "last_name" => "Rao", "department" => "Engineering",
      "country_code" => "IN", "country" => "India", "job_title" => "Engineering Specialist", "job_level" => "4",
      "employment_status" => "active", "hired_on" => "2019-04-01", "terminated_on" => "",
      "salary_amount" => "250000.00", "salary_currency" => "INR", "pay_frequency" => "monthly",
      "annual_base_local" => "3000000.00", "fx_rate_to_usd" => "0.01200000", "annual_base_usd" => "36000.00",
      "salary_effective_from" => "2024-01-01T09:00:00.000000Z"
    )
  end

  it "includes every status unless a status filter is given, and the terminated date" do
    rows = export
    expect(rows.drop(1).map { |r| r[8] }).to match_array(%w[active active active active on_leave terminated])
    expect(rows.find { |r| r[8] == "terminated" }[10]).to eq("2024-01-01")

    expect(export(status: "on_leave").drop(1).map(&:first)).to eq(%w[ACME-00004])
  end

  it "reuses the directory's filters, search, sort and direction, so list and export agree" do
    params = { country: "IN", q: "rao", sort: "annual_base_reporting", direction: "desc" }

    get "/api/v1/employees", params: params
    listed = json["data"].map { |row| row["employee_number"] }

    expect(export(params).drop(1).map(&:first)).to eq(listed)
    expect(listed).to eq(%w[ACME-00001 ACME-00006])
  end

  it "defaults to employee_number order" do
    expect(export.drop(1).map(&:first)).to eq(%w[ACME-00001 ACME-00002 ACME-00003 ACME-00004 ACME-00005 ACME-00006])
  end

  it "ignores page and per_page and exports every matching row" do
    expect(export(page: 99, per_page: 1).drop(1).size).to eq(6)
  end

  it "returns only the header row, with 200, for an empty result" do
    rows = export(q: "nobody-matches-this")

    expect(response).to have_http_status(:ok)
    expect(rows).to eq([ EXPORT_HEADER ])
  end

  it "reconciles active-only CSV row amounts with the dashboard total for the same filters" do
    [ {}, { country: "IN" }, { department: Department.find_by!(name: "Sales").id } ].each do |filters|
      get "/api/v1/analytics/summary", params: filters
      dashboard_total = BigDecimal(json.dig("data", "organization", "total_annual_base_reporting"))
      rows = export(filters.merge(status: "active"))
      usd_column = EXPORT_HEADER.index("annual_base_usd")
      exported_total = rows.drop(1).sum(BigDecimal("0")) { |row| BigDecimal(row.fetch(usd_column)) }

      expect(exported_total).to eq(dashboard_total)
    end
  end

  it "rejects invalid parameters with the JSON error body before any CSV is written" do
    get "/api/v1/employees/export.csv", params: { sort: "bogus" }

    expect(response).to have_http_status(:bad_request)
    expect(json["error"]["code"]).to eq("invalid_parameter")
  end

  describe "formula injection" do
    it "prefixes dangerous text cells, quotes special characters, and leaves numbers alone" do
      department = create_department("Engineering")
      employee = create(:employee, employee_number: "ACME-09100", first_name: "=cmd|' /C calc'!A0", last_name: "Smith, \"Jr\"",
                                   job_title: "-100.00", department: department)
      create(:salary_record, employee: employee, currency: Currency.find("USD"), amount: "12.50")

      row = EXPORT_HEADER.zip(export(q: "ACME-09100")[1]).to_h

      expect(row["first_name"]).to eq("'=cmd|' /C calc'!A0")
      expect(row["last_name"]).to eq("Smith, \"Jr\"")
      expect(row["job_title"]).to eq("'-100.00")
      expect(row["salary_amount"]).to eq("12.50")
      expect(row["job_level"]).to eq("4")
      expect(response.body).to include("\"Smith, \"\"Jr\"\"\"")
    end
  end

  describe "streaming in batches" do
    it "emits every row in directory order across several batches" do
      create_list(:employee, 25) # employee numbers ACME-10000 .. ACME-10024
      directory = Employees::Directory.new(ActionController::Parameters.new({}), paginated: false)

      batch_sizes = directory.each_batch(size: 10).map(&:size)
      numbers = directory.each_batch(size: 10).flat_map { |batch| batch.map(&:employee_number) }

      expect(batch_sizes).to eq([ 10, 10, 10, 1 ])
      expect(numbers).to eq(Employee.order(:employee_number, :id).pluck(:employee_number))
    end

    it "does not load the whole result set in one query" do
      create_list(:employee, 25)
      limits = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        limits << payload[:sql][/LIMIT (\d+)/, 1].to_i if payload[:sql].include?("LIMIT")
      end

      Employees::CsvExport.new(Employees::Directory.new(ActionController::Parameters.new({}), paginated: false)).each_line.to_a
      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(limits).to all(be <= 1000)
      expect(limits).not_to be_empty
    end
  end
end
