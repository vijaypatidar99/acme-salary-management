# One-time workflow entry point. It invokes the EXISTING db:seed task, not another generator.
require "uri"
require "json"
require "logger"

module NeonSeed
  class Refused < StandardError; end
  TABLES = %w[currencies countries departments exchange_rates employees salary_records].freeze

  class << self
    attr_accessor :phase
  end

  def self.check!(condition, message)
    raise Refused, message unless condition
  end

  def self.validate_config!(env = ENV)
    check!(env["RAILS_ENV"] == "production", "Rails environment must be production.")
    check!(env["CONFIRMATION"] == "SEED_NEON_10000", "Explicit seed confirmation is missing.")
    check!(env["ALLOW_PRODUCTION_SEED"] == "1", "Production seed opt-in is missing.")
    check!(env["RESET"].to_s.empty?, "RESET must be unset; destructive recovery is forbidden.")
    %w[DATABASE_URL NEON_EXPECTED_HOST SECRET_KEY_BASE].each do |name|
      check!(!env[name].to_s.strip.empty?, "A required database identity or Rails boot secret is missing.")
    end
    expected = env["NEON_EXPECTED_HOST"]
    check!(expected.match?(/\A[a-z0-9-]+(?:\.[a-z0-9-]+)*\.neon\.tech\z/), "Expected host must be an exact Neon hostname.")
    check!(!expected.split(".").first.end_with?("-pooler"), "Use the direct Neon endpoint, not the pooler.")
    url = URI.parse(env["DATABASE_URL"])
    check!(%w[postgres postgresql].include?(url.scheme) && url.host == expected && url.path == "/neondb", "Database URL does not match the independently configured Neon target.")
    check!(!url.user.to_s.empty? && !url.password.to_s.empty? && url.fragment.nil?, "Database URL must contain credentials and no fragment.")
    pairs = URI.decode_www_form(url.query.to_s)
    check!(pairs.map(&:first).uniq.length == pairs.length, "Duplicate connection parameters are forbidden.")
    check!((pairs.map(&:first) - %w[sslmode channel_binding connect_timeout sslrootcert]).empty?, "Unexpected connection overrides are forbidden.")
    check!(%w[require verify-full].include?(pairs.to_h["sslmode"]), "Database URL must explicitly require TLS (sslmode=require or verify-full).")
    %w[PGHOST PGHOSTADDR PGSERVICE PGSERVICEFILE PGDATABASE PGOPTIONS].each do |name|
      check!(env[name].to_s.empty?, "Remove inherited libpq connection overrides.")
    end
    expected
  rescue URI::InvalidURIError, ArgumentError
    raise Refused, "Database URL is malformed; check the secret without logging it."
  end

  def self.preflight!(connection, expected_host)
    check!(connection.select_value("SELECT current_schema()") == "public", "Expected the public application schema.")
    check!(connection.select_value("SELECT current_database()") == "neondb", "Connected database is not neondb.")
    check!(connection.raw_connection.host == expected_host, "Connected host does not match the expected Neon hostname.")
    check!(connection.select_value("SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()") == true, "The database session is not using TLS.")
    check!(connection.select_value("SHOW server_version_num").to_i.between?(180000, 189999), "Expected PostgreSQL major version 18.")
    TABLES.each do |table|
      check!(!connection.select_value("SELECT to_regclass('public.#{table}')").nil?, "Required application tables are missing; migrate separately.")
    end
    check!(connection.select_value("SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname='btree_gist')"), "btree_gist is missing.")
    check!(connection.select_value("SELECT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.salary_records'::regclass AND conname='salary_records_no_overlap' AND contype='x' AND convalidated)"), "Validated salary exclusion constraint is missing.")
    check!(connection.select_value("SELECT count(*) FROM pg_constraint WHERE conrelid IN ('public.employees'::regclass,'public.salary_records'::regclass,'public.exchange_rates'::regclass) AND NOT convalidated").to_i.zero?, "Application constraints are not all validated.")
    TABLES.each do |table|
      check!(connection.select_value("SELECT count(*) FROM public.#{table}").to_i.zero?, "Application data already exists; refusing to seed or overwrite it.")
    end
  end

  def self.run!
    self.phase = "configuration"
    expected_host = validate_config!
    return if ARGV == [ "--validate-config" ] # Offline validation only; never boots Rails/connects.
    check!(ARGV.empty?, "Unsupported arguments.")
    self.phase = "Rails boot"
    require_relative "../config/environment"
    check!(Rails.env.production?, "Rails did not boot in production.")
    Rails.logger = Logger.new(File::NULL)
    Rails.application.load_tasks
    Rake::Task["db:load_config"].invoke
    self.phase = "read-only preflight"
    ApplicationRecord.uncached do
      ApplicationRecord.connection_pool.with_connection do |connection|
        connection.transaction do
          connection.execute("SET TRANSACTION READ ONLY")
          preflight!(connection, expected_host)
        end
        # Serialize outside Actions too, prevent intervening API writes, and keep verification atomic.
        self.phase = "locked seed transaction"
        connection.transaction do
          check!(connection.select_value("SELECT pg_try_advisory_xact_lock(684771003)") == true, "Another seed session is active.")
          connection.execute("SET LOCAL lock_timeout = '5s'")
          connection.execute("LOCK TABLE #{TABLES.map { |table| "public.#{table}" }.join(', ')} IN SHARE ROW EXCLUSIVE MODE NOWAIT")
          preflight!(connection, expected_host) # Read-only checks repeated under the table locks.
          Rake::Task["db:seed"].invoke # Existing task: RAILS_ENV=production ALLOW_PRODUCTION_SEED=1 bin/rails db:seed
          self.phase = "post-seed verification"
          result = Seeds::DemoDataset.new.verify! # Existing history/gap/overlap/FX verification.
          check!(result[:employees] == 10_000 && result[:salary_records] == 16_055, "Seed counts do not match 10000 employees / 16055 salaries.")
          check!(result[:countries] == 6 && result[:departments] == 9 && result[:currencies] == 4 && ExchangeRate.count == 4, "Seed reference or FX counts are incorrect.")
          check!(result[:historical_records] == 6055 && result[:status_counts] == Seeds::DemoDataset::STATUS_WEIGHTS, "Seed history/status counts are incorrect.")
          check!(SalaryRecord.current.count == 10_000, "Open salary record count is incorrect.")
          self.phase = "transaction commit"
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # Boot/driver/Rake exceptions can contain connection strings. Never emit their raw messages,
  # backtraces or Rails SQL output to Actions, even if GitHub secret masking misses a substring.
  output = STDOUT.dup
  errors = STDERR.dup
  STDOUT.reopen(File::NULL, "w")
  STDERR.reopen(File::NULL, "w")
  begin
    NeonSeed.run!
    output.puts(ARGV.empty? ? "Neon seed committed and verified: 10000 employees, 16055 salaries, 10000 open records; reference and history invariants passed." : "Offline configuration checks passed; no connection or seed attempted.")
  rescue StandardError, SystemExit => error
    message = error.is_a?(NeonSeed::Refused) ? error.message : "#{NeonSeed.phase} failed. No automatic retry/reset was attempted; inspect the database read-only before any manual rerun."
    errors.puts("Neon seed refused/failed: #{message}")
    exit 1
  ensure
    STDOUT.reopen(output)
    STDERR.reopen(errors)
    output.close
    errors.close
  end
end
