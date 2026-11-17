import { QueryClient } from '@tanstack/react-query'
import { ApiError } from './api'

export function createQueryClient() {
  return new QueryClient({ defaultOptions: {
    queries: { staleTime: 30_000, retry: (attempt, error) => attempt < 1 && error instanceof ApiError && error.status === 0 },
    mutations: { retry: false },
  } })
}
