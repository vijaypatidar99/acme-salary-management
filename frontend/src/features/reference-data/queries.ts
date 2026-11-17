import { useQuery } from '@tanstack/react-query'
import { api, type QueryParams } from '../../lib/api'

export const useReferenceData = () => useQuery({
  queryKey: ['reference-data'], queryFn: ({ signal }) => api.referenceData(signal).then((r) => r.data), staleTime: 300_000,
})
export const useEmployees = (params: QueryParams) => useQuery({
  queryKey: ['employees', params], queryFn: ({ signal }) => api.employees(params, signal),
})
export const useEmployee = (id: string) => useQuery({
  queryKey: ['employee', id], queryFn: ({ signal }) => api.employee(id, signal).then((r) => r.data),
})
export const useAnalytics = (params: QueryParams) => useQuery({
  queryKey: ['analytics', params], queryFn: ({ signal }) => api.analytics(params, signal).then((r) => r.data),
})
