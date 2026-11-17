import { API_BASE_URL, HEALTH_PATH } from '../../lib/api'

// Resolves with the HTTP status. TanStack Query rejects a query that resolves to undefined,
// so this must return a value.
export async function fetchApiHealth(signal?: AbortSignal): Promise<number> {
  const response = await fetch(`${API_BASE_URL}${HEALTH_PATH}`, { signal })
  if (!response.ok) {
    throw new Error(`Health check failed with status ${response.status}`)
  }
  return response.status
}
