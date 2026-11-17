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

import type { AnalyticsSummary, EmployeeDetail, EmployeePage, Envelope, ErrorDetails, ReferenceData, RevisionInput, RevisionResult } from '../types/api'

export class ApiError extends Error {
  readonly status: number
  readonly code: string
  readonly details: ErrorDetails
  constructor(status: number, code: string, details: ErrorDetails = {}) {
    super(code)
    this.name = 'ApiError'
    this.status = status
    this.code = code
    this.details = details
  }
}

export type QueryParams = Record<string, string>
export const directoryFields = ['q', 'country', 'department', 'status', 'sort', 'direction', 'page', 'per_page'] as const
export const analyticsFields = ['country', 'department', 'job_level'] as const

export function queryParams(search: URLSearchParams, fields: readonly string[]): QueryParams {
  return Object.fromEntries(fields.flatMap((field) => {
    const value = search.get(field)
    return value ? [[field, value]] : []
  }))
}

function queryString(params: QueryParams, fields: readonly string[]) {
  return new URLSearchParams(Object.entries(params).filter(([key, value]) => fields.includes(key) && value !== '')).toString()
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  let response: Response
  try {
    response = await fetch(`${API_BASE_URL}/api/v1${path}`, {
      ...options, credentials: 'omit', redirect: 'error',
      headers: { Accept: 'application/json', ...options.headers },
    })
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') throw error
    throw new ApiError(0, 'network_error')
  }
  let body
  try { body = await response.json() } catch { throw new ApiError(response.status, 'invalid_response') }
  if (!response.ok) throw new ApiError(response.status, body.error?.code ?? 'internal_error', body.error?.details ?? {})
  return body as T
}

export const api = {
  employees: (params: QueryParams, signal?: AbortSignal) => request<EmployeePage>(`/employees?${queryString(params, directoryFields)}`, { signal }),
  employee: (id: string, signal?: AbortSignal) => request<Envelope<EmployeeDetail>>(`/employees/${encodeURIComponent(id)}`, { signal }),
  referenceData: (signal?: AbortSignal) => request<Envelope<ReferenceData>>('/reference_data', { signal }),
  analytics: (params: QueryParams, signal?: AbortSignal) => request<Envelope<AnalyticsSummary>>(`/analytics/summary?${queryString(params, analyticsFields)}`, { signal }),
  revise: (id: number, input: RevisionInput, writeKey: string) => request<Envelope<RevisionResult>>(`/employees/${id}/salary_revisions`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${writeKey}` },
    body: JSON.stringify({ salary_revision: input }),
  }),
  exportUrl: (params: QueryParams) => `${API_BASE_URL}/api/v1/employees/export.csv?${queryString(params, directoryFields.filter((key) => key !== 'page' && key !== 'per_page'))}`,
}
