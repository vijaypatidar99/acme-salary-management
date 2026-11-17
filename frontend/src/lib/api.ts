const DEV_API_BASE_URL = 'http://localhost:3000'

// The API origin comes from the build environment (see .env.example), never from code.
function resolveApiBaseUrl(): string {
  const configured = import.meta.env.VITE_API_BASE_URL
  if (configured) return configured.replace(/\/+$/, '')
  if (import.meta.env.DEV) return DEV_API_BASE_URL
  throw new Error('VITE_API_BASE_URL must be set for production builds')
}

export const API_BASE_URL = resolveApiBaseUrl()

// Framework health route; outside /api/v1 and not part of the API contract.
export const HEALTH_PATH = '/up'
