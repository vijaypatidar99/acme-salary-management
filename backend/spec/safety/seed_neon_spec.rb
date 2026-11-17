require "spec_helper"
require "open3"
require "rbconfig"
require_relative "../../script/seed_neon"

# No Rails boot, production secrets, or database connections in these tests.
RSpec.describe NeonSeed do
  let(:host) { "ep-offline-test.us-east-2.aws.neon.tech" }
  let(:config) do
    { "RAILS_ENV" => "production", "CONFIRMATION" => "SEED_NEON_10000", "ALLOW_PRODUCTION_SEED" => "1",
      "DATABASE_URL" => "postgresql://offline:unused-test-password@#{host}/neondb?sslmode=require", "NEON_EXPECTED_HOST" => host,
      "SECRET_KEY_BASE" => "unused-offline-test-value" }
  end

  it "accepts an exact target with TLS, including certificate verification" do
    expect(described_class.validate_config!(config)).to eq(host)
    expect(described_class.validate_config!(config.merge("DATABASE_URL" => config["DATABASE_URL"].sub("sslmode=require", "sslmode=verify-full")))).to eq(host)
  end

  it "rejects missing secrets, wrong confirmation/environment, and destructive flags" do
    [ { "DATABASE_URL" => "" }, { "NEON_EXPECTED_HOST" => "" }, { "SECRET_KEY_BASE" => "" },
      { "CONFIRMATION" => "wrong" }, { "RAILS_ENV" => "development" }, { "ALLOW_PRODUCTION_SEED" => "" },
      { "RESET" => "1" }, { "PGSERVICE" => "hidden" } ].each do |override|
      expect { described_class.validate_config!(config.merge(override)) }.to raise_error(described_class::Refused)
    end
  end

  it "rejects wrong database/host, poolers, duplicate TLS flags and connection overrides" do
    [ config["DATABASE_URL"].sub("/neondb?", "/other?"), config["DATABASE_URL"].sub(host, "ep-other.neon.tech"),
      config["DATABASE_URL"].sub("sslmode=require", "sslmode=disable"),
      config["DATABASE_URL"].sub("sslmode=require", "sslmode=prefer"),
      config["DATABASE_URL"].sub("?sslmode=require", ""), config["DATABASE_URL"] + "&sslmode=disable",
      config["DATABASE_URL"] + "&host=elsewhere", "not a valid URL" ].each do |url|
      expect { described_class.validate_config!(config.merge("DATABASE_URL" => url)) }.to raise_error(described_class::Refused)
    end
    expect { described_class.validate_config!(config.merge("NEON_EXPECTED_HOST" => "ep-test-pooler.us-east-2.aws.neon.tech")) }.to raise_error(described_class::Refused)
  end

  class ReadOnlyConnection
    RawClient = Struct.new(:host, :tls) do
      def ssl_in_use? = tls
    end

    attr_reader :queries, :client
    attr_accessor :overrides
    def initialize(host)
      @client = RawClient.new(host, true)
      @queries = []
      @overrides = {}
    end
    def raw_connection = client
    def select_value(sql)
      @queries << sql
      return overrides[sql] if overrides.key?(sql)
      return "public" if sql == "SELECT current_schema()"
      return "neondb" if sql == "SELECT current_database()"
      return "180000" if sql == "SHOW server_version_num"
      return "table" if sql.include?("to_regclass")
      return 0 if sql.start_with?("SELECT count(*)")
      true
    end
  end

  it "performs only SELECT/SHOW preflight queries and checks every table is empty" do
    connection = ReadOnlyConnection.new(host)
    described_class.preflight!(connection, host)
    expect(connection.queries).to all(match(/\A(?:SELECT|SHOW) /))
    described_class::TABLES.each { |table| expect(connection.queries).to include("SELECT count(*) FROM public.#{table}") }
  end

  it "accepts active client TLS even when Neon's backend pg_stat_ssl would be false" do
    connection = ReadOnlyConnection.new(host)
    connection.overrides["SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()"] = false
    expect { described_class.preflight!(connection, host) }.not_to raise_error
    expect(connection.queries.grep(/pg_stat_ssl/)).to be_empty
  end

  it "fails closed for inactive or indeterminate client TLS, regardless of server-side SSL" do
    [ false, nil ].each do |tls|
      connection = ReadOnlyConnection.new(host)
      connection.client.tls = tls
      connection.overrides["SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()"] = true
      expect { described_class.preflight!(connection, host) }.to raise_error(described_class::Refused, /client connection is not using TLS/)
      expect(connection.queries.grep(/count\(\*\)/)).to be_empty
    end
  end

  it "refuses nonempty/missing tables, wrong identity and missing extensions" do
    [ [ "SELECT count(*) FROM public.employees", 1 ], [ "SELECT count(*) FROM public.salary_records", 1 ],
      [ "SELECT count(*) FROM public.currencies", 1 ], [ "SELECT to_regclass('public.employees')", nil ],
      [ "SELECT current_database()", "other" ], [ "SELECT current_schema()", "other" ],
      [ "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname='btree_gist')", false ] ].each do |query, value|
      connection = ReadOnlyConnection.new(host)
      connection.overrides[query] = value
      expect { described_class.preflight!(connection, host) }.to raise_error(described_class::Refused)
    end
    expect { described_class.preflight!(ReadOnlyConnection.new("elsewhere.neon.tech"), host) }.to raise_error(described_class::Refused)
  end

  it "supports offline subprocess validation without booting Rails or printing credentials" do
    env = config.merge(%w[PGHOST PGHOSTADDR PGSERVICE PGSERVICEFILE PGDATABASE PGOPTIONS].to_h { |name| [ name, nil ] })
    script = File.expand_path("../../script/seed_neon.rb", __dir__)
    output, error, status = Open3.capture3(env, RbConfig.ruby, script, "--validate-config")
    expect(status).to be_success, error
    expect(output).to include("no connection or seed attempted")
    output, error, status = Open3.capture3(env.merge("RESET" => "1"), RbConfig.ruby, script, "--validate-config")
    expect(status).not_to be_success
    expect(output + error).not_to include("unused-test-password", config["DATABASE_URL"], config["SECRET_KEY_BASE"])
    expect(error).to include("RESET must be unset")
  end
end
