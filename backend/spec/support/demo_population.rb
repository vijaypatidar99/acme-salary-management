# A small, fully hand-computable organization used by the directory, export and analytics specs.
#
#   #  number      name          country dept         level status      salary                 annual USD
#   1  ACME-00001  Asha Rao      IN      Engineering  4     active      INR 250,000.00 /month  36,000.00
#   2  ACME-00002  Ben Carter    US      Engineering  3     active      USD  90,000.00 /year   90,000.00
#   3  ACME-00003  Clara Weiss   DE      Sales        5     active      EUR   3,333.33 /month  43,199.96
#   4  ACME-00004  Dev Patel     IN      Sales        2     on_leave    INR 100,000.00 /month  14,400.00 (not counted)
#   5  ACME-00005  Eli Brown     US      Sales        4     terminated  USD  70,000.00 /year   70,000.00 (not counted)
#   6  ACME-00006  Gita Rao      IN      Engineering  1     active      INR 120,000.00 /month  17,280.00
module DemoPopulation
  ROWS = [
    [ "ACME-00001", "Asha", "Rao", "IN", "Engineering", 4, "active", "INR", "250000.00", "monthly", "0.012", "2019-04-01" ],
    [ "ACME-00002", "Ben", "Carter", "US", "Engineering", 3, "active", "USD", "90000.00", "annual", "1.0", "2020-02-01" ],
    [ "ACME-00003", "Clara", "Weiss", "DE", "Sales", 5, "active", "EUR", "3333.33", "monthly", "1.08", "2018-06-15" ],
    [ "ACME-00004", "Dev", "Patel", "IN", "Sales", 2, "on_leave", "INR", "100000.00", "monthly", "0.012", "2021-01-10" ],
    [ "ACME-00005", "Eli", "Brown", "US", "Sales", 4, "terminated", "USD", "70000.00", "annual", "1.0", "2017-03-01" ],
    [ "ACME-00006", "Gita", "Rao", "IN", "Engineering", 1, "active", "INR", "120000.00", "monthly", "0.012", "2022-09-01" ]
  ].freeze

  COUNTRY_NAMES = { "IN" => "India", "US" => "United States", "DE" => "Germany" }.freeze

  def create_demo_population
    create_currencies_and_rates
    ROWS.map do |number, first, last, country, department, level, status, currency, amount, frequency, rate, hired|
      employee = Employee.create!(
        employee_number: number, first_name: first, last_name: last, job_title: "#{department} Specialist", job_level: level,
        department: create_department(department), country: create_country(country, COUNTRY_NAMES.fetch(country)),
        employment_status: status, hired_on: hired, terminated_on: (status == "terminated" ? "2024-01-01" : nil)
      )
      employee.salary_records.create!(amount: amount, currency_code: currency, pay_frequency: frequency, fx_rate: rate,
                                      effective_from: Time.utc(2024, 1, 1, 9), reason: "Initial salary")
      employee
    end
  end

  def json
    response.parsed_body
  end
end

RSpec.configure { |config| config.include DemoPopulation }
