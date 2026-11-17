import { QueryClient } from '@tanstack/react-query'

// A factory so tests get an isolated cache.
export function createQueryClient() {
  return new QueryClient()
}
