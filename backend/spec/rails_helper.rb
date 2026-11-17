require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
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
