require "ipaddr"
require "uri"

# Loaded BEFORE Rails: all current suite connections use the PostgreSQL adapter factory below.
# A database name is not evidence of isolation. The owner must explicitly attest a disposable DB.
module TestDatabaseSafety
  class UnsafeTarget < StandardError; end
  FORBIDDEN = %w[backend_development backend_production postgres template0 template1].freeze

  def self.reject!
    raise UnsafeTarget, "RSpec requires test mode and an explicitly attested local disposable database; see backend/README.md"
  end

  def self.local_host?(host)
    return true if host.to_s.start_with?("/") && !host.to_s.include?(",")
    return true if host == "localhost"

    IPAddr.new(host.to_s).loopback?
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.configure!
    reject! if ENV["RAILS_ENV"] && ENV["RAILS_ENV"] != "test"
    reject! if ENV["RACK_ENV"] && ENV["RACK_ENV"] != "test"
    ENV["RAILS_ENV"] = "test"
    @database = ENV.fetch("ACME_TEST_DATABASE", "")
    @token = ENV.fetch("ACME_TEST_DATABASE_TOKEN", "")
    reject! unless @database.match?(/\A[a-z][a-z0-9_]{0,62}\z/) && !FORBIDDEN.include?(@database)
    reject! unless @token.match?(/\A[0-9a-f]{64}\z/)
    if ENV["DATABASE_URL"]
      url = URI.parse(ENV["DATABASE_URL"])
      reject! unless %w[postgres postgresql].include?(url.scheme) && url.path == "/#{@database}"
      reject! if url.host && !url.host.empty? && !local_host?(url.host)
      reject! if url.query # No hidden service/host/database overrides.
    end
  rescue URI::InvalidURIError
    reject!
  end

  def self.validate_parameters!(params)
    reject! unless ENV["RAILS_ENV"] == "test" && params[:dbname] == @database
    reject! if FORBIDDEN.include?(params[:dbname]) || params[:service] || ENV["PGSERVICE"] || ENV["PGSERVICEFILE"]
    host = params[:host] || ENV["PGHOST"] || "/tmp"
    reject! unless local_host?(host)
    address = params[:hostaddr] || ENV["PGHOSTADDR"]
    reject! if address && !local_host?(address)
  end

  def self.validate_connection!(connection)
    # The new connection is read-only until actual identity/attestation has been checked.
    row = connection.exec(<<~SQL).first
      SELECT current_database() AS database, inet_server_addr()::text AS address,
             shobj_description(oid, 'pg_database') AS marker,
             pg_get_userbyid(datdba) = current_user AS owned,
             pg_is_in_recovery() AS recovery
      FROM pg_database WHERE datname = current_database()
    SQL
    reject! unless row && row["database"] == @database && row["marker"] == "acme-rspec-disposable:#{@token}"
    reject! unless row["owned"] == "t" && row["recovery"] == "f"
    reject! if row["address"] && !local_host?(row["address"])
    reject! unless local_host?(connection.host)
  end

  module ConnectionGuard
    def new_client(params)
      TestDatabaseSafety.validate_parameters!(params)
      # Override inherited options in the SAFE direction until identity is proved.
      options = [ params[:options], "-c default_transaction_read_only=on" ].compact.join(" ")
      connection = super(params.merge(options: options))
      begin
        TestDatabaseSafety.validate_connection!(connection)
        connection.exec("SET default_transaction_read_only = off")
        connection
      rescue StandardError
        connection.close
        raise
      end
    end
  end
end
