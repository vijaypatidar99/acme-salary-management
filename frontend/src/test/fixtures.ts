import { vi } from 'vitest'
import type { AnalyticsSummary, EmployeeDetail, ReferenceData, SalaryRecord } from '../types/api'

export const salary: SalaryRecord = {
  id: 9001, amount: '250000.00', currency: 'INR', pay_frequency: 'monthly', fx_rate: '0.01200000',
  annual_base_local: '3000000.00', annual_base_reporting: '36000.00', effective_from: '2025-04-01T09:00:00.123456Z', effective_to: null, reason: 'Annual review', is_current: true,
}
export const employee: EmployeeDetail = {
  id: 42, employee_number: 'ACME-00042', first_name: 'Asha', last_name: 'Rao', job_title: 'Senior Engineer', job_level: 4,
  department: { id: 3, name: 'Engineering' }, country: { code: 'IN', name: 'India' }, employment_status: 'active', hired_on: '2019-04-01', terminated_on: null,
  can_revise_salary: true, current_salary: salary, salary_history: [salary, { ...salary, id: 8120, amount: '230000.00', effective_from: '2023-04-01T00:00:00.000000Z', effective_to: salary.effective_from, is_current: false, reason: 'Promotion' }], reporting_currency: 'USD',
}
export const references: ReferenceData = {
  reporting_currency: 'USD', countries: [{ code: 'IN', name: 'India' }, { code: 'US', name: 'United States' }], departments: [{ id: 3, name: 'Engineering' }, { id: 5, name: 'Sales' }],
  currencies: [{ code: 'INR', name: 'Indian Rupee', has_rate: true }, { code: 'USD', name: 'US Dollar', has_rate: true }, { code: 'JPY', name: 'Japanese Yen', has_rate: false }],
  employment_statuses: ['active', 'on_leave', 'terminated'], pay_frequencies: ['monthly', 'annual'], job_levels: [1, 2, 3, 4, 5, 6, 7], low_sample_threshold: 10,
}
const metrics = { active_headcount: 2, total_annual_base_reporting: '126000.00', average_annual_base_reporting: '63000.00', median_annual_base_reporting: '63000.00', low_sample: true }
export const analytics: AnalyticsSummary = {
  reporting_currency: 'USD', filters: { country: null, department: null, job_level: null }, organization: { ...metrics, status_counts: { active: 2, on_leave: 1, terminated: 1 } },
  by_country: [{ ...metrics, country: { code: 'IN', name: 'India' }, local_totals: [{ currency: 'INR', active_headcount: 2, total_annual_base_local: '10500000.00' }] }],
  by_department: [{ ...metrics, department: { id: 3, name: 'Engineering' } }], notes: ['Reporting-currency values use fixed illustrative exchange rates.'],
}
export const jsonResponse = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
export const apiFailure = (status: number, code: string, details: Record<string, unknown> = {}) => jsonResponse({ error: { code, message: 'Test error', details } }, status)
export function mockApi(override?: (url: URL, init?: RequestInit) => Response | Promise<Response> | undefined) {
  const mock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input))
    const custom = override?.(url, init)
    if (custom) return custom
    if (url.pathname.endsWith('/reference_data')) return jsonResponse({ data: references })
    if (url.pathname.endsWith('/analytics/summary')) return jsonResponse({ data: analytics })
    if (url.pathname.endsWith('/employees/42')) return jsonResponse({ data: employee })
    if (url.pathname.endsWith('/employees')) return jsonResponse({ data: [employee], meta: { page: Number(url.searchParams.get('page') ?? 1), per_page: Number(url.searchParams.get('per_page') ?? 25), total_count: 60, total_pages: 3, reporting_currency: 'USD' } })
    if (url.pathname === '/up') return new Response(null, { status: 200 })
    return apiFailure(404, 'not_found')
  })
  vi.stubGlobal('fetch', mock)
  return mock
}
