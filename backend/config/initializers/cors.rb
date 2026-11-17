# Cross-origin access for the separately hosted SPA (docs/architecture.md §8; hosting and
# CORS handling are still pending under DR-22).
#
# Only origins listed in CORS_ALLOWED_ORIGINS (comma-separated) are allowed; there is no
# wildcard. In development and test the local Vite dev server is allowed by default.
# Production allows nothing unless the variable is set.
local_vite_origins = %w[ http://localhost:5173 http://127.0.0.1:5173 ]
configured_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
if configured_origins.include?("*")
  raise ArgumentError, "CORS_ALLOWED_ORIGINS must list explicit origins, never a wildcard"
end
allowed_origins = configured_origins.presence || (Rails.env.local? ? local_vite_origins : [])

if allowed_origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed_origins)

      # Read-only health check, plus the versioned API (writes send an Authorization header).
      resource "/up", headers: :any, methods: [ :get, :head, :options ]
      resource "/api/*",
               headers: %w[ Authorization Content-Type Accept ],
               methods: [ :get, :post, :head, :options ],
               max_age: 600
    end
  end
end
