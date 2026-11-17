import { useQuery } from '@tanstack/react-query'
import { fetchApiHealth } from './health'

export function useApiHealth() {
  return useQuery({
    queryKey: ['api-health'],
    queryFn: ({ signal }) => fetchApiHealth(signal),
    // A status indicator should report a failure immediately, not after retries.
    retry: false,
  })
}
