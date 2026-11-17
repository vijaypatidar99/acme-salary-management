require_relative "test_database_safety"
begin
  TestDatabaseSafety.configure!
rescue TestDatabaseSafety::UnsafeTarget => error
  abort error.message
end
require "spec_helper"
require_relative "../config/boot"
require "active_record"
require "active_record/connection_adapters/postgresql_adapter"
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.singleton_class.prepend(TestDatabaseSafety::ConnectionGuard)
require_relative "../config/environment"
abort "RSpec requires the Rails test environment" unless Rails.env.test?
# Force identity validation before schema maintenance or any fixture hooks run.
ActiveRecord::Base.connection_pool.with_connection(&:verify!)
require "rspec/rails"

# Support code (helpers) lives in spec/support.
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

# Keeps the test database in line with db/schema.rb; loads the schema when migrations are pending.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Each example runs in a transaction that is rolled back. Specs that need real
  # concurrency (two connections) must opt out explicitly.
  config.use_transactional_fixtures = true

  # Spec type (request, model, ...) follows the directory: spec/requests -> type: :request.
  config.infer_spec_type_from_file_location!

  config.include FactoryBot::Syntax::Methods

  config.filter_rails_from_backtrace!
end
