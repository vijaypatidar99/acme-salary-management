# Run via bin/rails runner after sourcing script/prepare_test_database.rb's environment file.
require_relative "../spec/test_database_safety"
TestDatabaseSafety.configure!
require "active_record/connection_adapters/postgresql_adapter"
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.singleton_class.prepend(TestDatabaseSafety::ConnectionGuard)
ApplicationRecord.connection_pool.disconnect!
ApplicationRecord.connection_pool.with_connection(&:verify!)
abort "QA fixture requires an empty attested disposable database" unless [ Employee, SalaryRecord, Country, Department, Currency, ExchangeRate ].all? { |model| model.count.zero? }

ApplicationRecord.transaction do
  Seeds::DemoDataset.call(employee_count: 300)
  employee = Employee.create!(id: 10_001, employee_number: "QA-LOCAL-10001", first_name: "Local QA", last_name: "Long History",
                              job_title: "Synthetic verification fixture", job_level: 4, department: Department.first,
                              country: Country.find("US"), employment_status: "active", hired_on: Date.new(2010, 1, 1))
  start = Time.utc(2019, 1, 1, 9, 0, 0, 123_456)
  rows = 1000.times.map do |index|
    { employee_id: employee.id, amount: "1000.00", currency_code: "USD", pay_frequency: "annual", fx_rate: "1.0",
      effective_from: start + index * 86_400, effective_to: index == 999 ? nil : start + (index + 1) * 86_400,
      reason: "Synthetic long-history fixture #{index + 1}", created_at: start, updated_at: start }
  end
  SalaryRecord.insert_all!(rows)
end
puts "Prepared 300 small-seed employees plus QA-LOCAL-10001 with 1,000 contiguous salary records. Disposable DB only."
