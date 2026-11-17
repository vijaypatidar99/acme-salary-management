require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # All supported platforms (Render, Railway, Fly.io) terminate TLS at their edge proxy and forward
  # requests to the Rails process over HTTP on an internal network. `assume_ssl` tells Rails to treat
  # every incoming request as HTTPS (sets `request.ssl? = true`, adds Strict-Transport-Security),
  # without issuing an http→https redirect that would loop on the internal connection.
  #
  # Do NOT enable `force_ssl` here: that adds a redirect middleware that fires before the proxy
  # strips the original scheme, causing an infinite redirect loop on platforms that forward plain
  # HTTP internally. TLS enforcement is the platform edge's responsibility; Rails enforces it only
  # through HSTS (which `assume_ssl` already sets).
  config.assume_ssl = true

  # Strict-Transport-Security is sent automatically by `assume_ssl`. No separate ssl_options line
  # is needed. The /up health check is exempt from HSTS by default.

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # DNS rebinding protection: restrict the Host header to the declared API origin.
  # Set RAILS_ALLOWED_HOSTS in the platform environment to the actual backend hostname, e.g.:
  #   RAILS_ALLOWED_HOSTS=acme-api.onrender.com
  # Multiple hosts: comma-separate them. Leave unset (or set to "") to skip the check during
  # initial deployment smoke-testing, then lock it down before sharing the write key.
  if (hosts_env = ENV.fetch("RAILS_ALLOWED_HOSTS", "")).present?
    config.hosts = hosts_env.split(",").map(&:strip)
    # Health-check requests from the platform itself may use an internal IP or the container
    # hostname rather than the public domain; exclude /up so deploys do not stall.
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
