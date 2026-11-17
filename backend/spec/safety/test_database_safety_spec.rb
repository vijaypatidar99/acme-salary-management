require "spec_helper"
require "open3"
require "rbconfig"

# Deliberately does NOT load rails_helper or open a database. Runs before mutating specs.
RSpec.describe "Test database safety subprocesses" do
  def probe(code, overrides = {})
    env = { "RAILS_ENV" => "test", "RACK_ENV" => nil, "DATABASE_URL" => nil,
            "ACME_TEST_DATABASE" => "deliberately_disposable", "ACME_TEST_DATABASE_TOKEN" => "a" * 64,
            "PGHOST" => nil, "PGHOSTADDR" => nil, "PGSERVICE" => nil, "PGSERVICEFILE" => nil }.merge(overrides)
    Open3.capture3(env, RbConfig.ruby, "-r", File.expand_path("../test_database_safety", __dir__), "-e", code)
  end

  it "supports explicitly attested socket and loopback URL configurations" do
    [ "postgresql:///deliberately_disposable", "postgresql://127.0.0.1/deliberately_disposable" ].each do |url|
      _output, error, status = probe("TestDatabaseSafety.configure!", "DATABASE_URL" => url)
      expect(status).to be_success, error
    end
  end

  it "rejects development and production before Rails or a connection can load" do
    %w[development production].each do |mode|
      output, _error, status = probe('TestDatabaseSafety.configure!; puts "UNSAFE_CONTINUATION"', "RAILS_ENV" => mode)
      expect(status).not_to be_success
      expect(output).not_to include("UNSAFE_CONTINUATION")
    end
  end

  it "rejects unsafe configuration through the real rails_helper entry point before Rails boot" do
    helper = File.expand_path("../rails_helper", __dir__)
    code = "require 'rspec/core'; $LOAD_PATH.unshift(#{File.expand_path('..', __dir__).inspect}); require #{helper.inspect}; puts 'UNSAFE_CONTINUATION'"
    [ { "RAILS_ENV" => "development" }, { "RAILS_ENV" => "production" },
     { "DATABASE_URL" => "postgresql:///backend_development" } ].each do |env|
      output, error, status = probe(code, env)
      expect(status).not_to be_success
      expect(output).not_to include("UNSAFE_CONTINUATION")
      expect(error).to include("explicitly attested")
    end
  end

  it "fails closed for missing attestation, mismatched URLs, remote hosts and protected names" do
    [ { "ACME_TEST_DATABASE_TOKEN" => nil }, { "ACME_TEST_DATABASE" => "backend_development" },
      { "DATABASE_URL" => "postgresql:///backend_development" },
      { "DATABASE_URL" => "postgresql://hosted.example/deliberately_disposable" },
      { "DATABASE_URL" => "postgresql:///deliberately_disposable?host=hosted.example" },
      { "RACK_ENV" => "development" } ].each do |env|
      _output, _error, status = probe("TestDatabaseSafety.configure!", env)
      expect(status).not_to be_success
    end
  end

  it "rejects every later unsafe connection BEFORE the factory is called" do
    code = <<~'CODE'
      TestDatabaseSafety.configure!
      class Factory
        def self.new_client(*) = abort("FACTORY_WAS_CALLED")
        singleton_class.prepend(TestDatabaseSafety::ConnectionGuard)
      end
      [{dbname: "backend_development"}, {dbname: "deliberately_disposable", host: "remote.example"},
       {dbname: "deliberately_disposable", service: "hidden"}, {dbname: "deliberately_disposable", hostaddr: "192.0.2.1"}].each do |params|
        begin
          Factory.new_client(params)
          abort "not rejected"
        rescue TestDatabaseSafety::UnsafeTarget
        end
      end
      puts "rejected before connect"
    CODE
    output, error, status = probe(code)
    expect(status).to be_success, error
    expect(output).to include("rejected before connect")
  end

  it "verifies actual identity on each new connection and closes unverified connections before enabling writes" do
    code = <<~'CODE'
      TestDatabaseSafety.configure!
      class Connection
        attr_reader :commands, :closed
        def initialize(row) = (@row = row; @commands = [])
        def host = "/tmp"
        def exec(sql)
          @commands << sql
          [@row]
        end
        def close = @closed = true
      end
      class Factory
        class << self
          attr_accessor :next_connection, :options
          def new_client(params)
            self.options = params[:options]
            next_connection
          end
          prepend TestDatabaseSafety::ConnectionGuard
        end
      end
      good = {"database" => "deliberately_disposable", "marker" => "acme-rspec-disposable:#{'a' * 64}", "address" => nil, "owned" => "t", "recovery" => "f"}
      connection = Connection.new(good)
      Factory.next_connection = connection
      Factory.new_client(dbname: "deliberately_disposable")
      abort unless connection.commands.last == "SET default_transaction_read_only = off"
      abort unless Factory.options.end_with?("default_transaction_read_only=on")
      [{"marker" => nil}, {"database" => "backend_development"}, {"address" => "192.0.2.1"}, {"owned" => "f"}, {"recovery" => "t"}].each do |bad|
        connection = Connection.new(good.merge(bad))
        Factory.next_connection = connection
        begin
          Factory.new_client(dbname: "deliberately_disposable")
          abort "not rejected"
        rescue TestDatabaseSafety::UnsafeTarget
          abort unless connection.closed && connection.commands.none? { |sql| sql.include?("read_only = off") }
        end
      end
      puts "identity checked every time"
    CODE
    output, error, status = probe(code)
    expect(status).to be_success, error
    expect(output).to include("identity checked every time")
  end
end
