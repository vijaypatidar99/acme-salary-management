require "rails_helper"

RSpec.describe Employees::Directory do
  before { create_demo_population }

  def directory(params = {}, **options)
    described_class.new(ActionController::Parameters.new(params), **options)
  end

  def invalid_parameter(params)
    directory(params)
    nil
  rescue DomainError => e
    e
  end

  it "defaults to page 1, 25 per page, ordered by employee number" do
    page = directory.page

    expect(page).to have_attributes(page: 1, per_page: 25, total_count: 6, total_pages: 1)
    expect(page.records.map(&:employee_number)).to eq(%w[ACME-00001 ACME-00002 ACME-00003 ACME-00004 ACME-00005 ACME-00006])
  end

  it "exposes the joined names and the current salary on each record without extra queries" do
    record = directory({ q: "ACME-00003" }).page.records.first

    expect(record["country_name"]).to eq("Germany")
    expect(record["department_name"]).to eq("Sales")
    expect(record["annual_base_reporting"]).to eq(BigDecimal("43199.96"))
    expect(record["salary_currency"]).to eq("EUR")
  end

  it "ignores paging parameters when not paginated (the export)" do
    batches = directory({ page: "abc", per_page: "9999" }, paginated: false).each_batch(size: 4).to_a

    expect(batches.map(&:size)).to eq([ 4, 2 ])
  end

  it "reports the offending parameter in the error details" do
    error = invalid_parameter(per_page: "101")

    expect(error.code).to eq("invalid_parameter")
    expect(error.status).to eq(:bad_request)
    expect(error.details).to eq("per_page" => [ "must be between 1 and 100" ])
  end

  it "never lets an unlisted sort reach the ORDER BY clause" do
    error = invalid_parameter(sort: "employees.id; DROP TABLE employees")

    expect(error.code).to eq("invalid_parameter")
    expect(Employee.count).to eq(6)
  end

  it "puts employees without a current salary last when sorting by salary" do
    no_salary = create(:employee, employee_number: "ACME-09999")

    ascending = directory({ sort: "annual_base_reporting", direction: "asc" }).page.records.map(&:employee_number)
    descending = directory({ sort: "annual_base_reporting", direction: "desc" }).page.records.map(&:employee_number)

    expect(ascending.last).to eq(no_salary.employee_number)
    expect(descending.last).to eq(no_salary.employee_number)
  end
end
