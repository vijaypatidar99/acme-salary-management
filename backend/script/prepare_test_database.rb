#!/usr/bin/env ruby
require_relative "../config/boot"
require "pg"
require "ipaddr"
require "securerandom"
require "tempfile"
require "shellwords"

# Creates a NEW local database only. Never adopts, resets or drops an existing database.
host = ENV.fetch("PGHOST", "/tmp")
local = host.start_with?("/") || host == "localhost" || (IPAddr.new(host).loopback? rescue false)
abort "Use an explicit local PostgreSQL socket/loopback host" unless local && !host.include?(",")
abort "Remove libpq service/address overrides first" if ENV["PGSERVICE"] || ENV["PGSERVICEFILE"] || ENV["PGHOSTADDR"]
port = ENV.fetch("PGPORT", "5432")
database = ARGV.fetch(0) { "acme_qa_#{Process.pid}_#{SecureRandom.hex(4)}" }
abort "Use a simple new disposable database name" unless database.match?(/\A[a-z][a-z0-9_]{0,62}\z/)
abort "Protected database name" if %w[backend_development backend_production backend_test postgres template0 template1].include?(database)
admin = PG.connect(host: host, port: port, dbname: "postgres")
address = admin.exec("SELECT inet_server_addr()::text AS address").first["address"]
abort "PostgreSQL must be local, not a forwarded hosted connection" if address && !IPAddr.new(address).loopback?
abort "Database already exists; refusing to alter it" if admin.exec_params("SELECT 1 FROM pg_database WHERE datname=$1", [ database ]).ntuples.positive?
token = SecureRandom.hex(32)
identifier = PG::Connection.quote_ident(database)
admin.exec("CREATE DATABASE #{identifier}")
admin.exec("COMMENT ON DATABASE #{identifier} IS #{admin.escape_literal("acme-rspec-disposable:#{token}")}")
admin.close
env = { "RAILS_ENV" => "test", "RACK_ENV" => "test", "PGHOST" => host, "PGPORT" => port,
        "DATABASE_URL" => "postgresql:///#{database}", "ACME_TEST_DATABASE" => database, "ACME_TEST_DATABASE_TOKEN" => token }
Dir.chdir(File.expand_path("..", __dir__)) { system(env, "bin/rails", "db:schema:load", exception: true) }
file = Tempfile.create([ "acme-test-", ".env" ])
file.chmod(0o600)
file.write(env.map { |key, value| "export #{key}=#{Shellwords.escape(value)}\n" }.join)
file.close
puts "Prepared NEW disposable database #{database}. No seed/reset/drop performed."
puts "Source #{file.path} in the test terminal before running RSpec. Keep this file local."
