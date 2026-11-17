export interface Country { code: string; name: string }
export interface Department { id: number; name: string }
export type EmploymentStatus = 'active' | 'on_leave' | 'terminated'
export type PayFrequency = 'monthly' | 'annual'
export interface SalarySummary {
  id: number
  amount: string
  currency: string
  pay_frequency: PayFrequency
  annual_base_local: string
  annual_base_reporting: string
  effective_from: string
}
export interface SalaryRecord extends SalarySummary {
  fx_rate: string
  effective_to: string | null
  reason: string
  is_current: boolean
}
export interface Employee {
  id: number
  employee_number: string
  first_name: string
  last_name: string
  job_title: string
  job_level: number
  department: Department
  country: Country
  employment_status: EmploymentStatus
  hired_on: string
  current_salary: SalarySummary | null
}
export interface EmployeeDetail extends Omit<Employee, 'current_salary'> {
  current_salary: SalaryRecord | null
  terminated_on: string | null
  can_revise_salary: boolean
  salary_history: SalaryRecord[]
  reporting_currency: string
}
export interface EmployeePage {
  data: Employee[]
  meta: { page: number; per_page: number; total_count: number; total_pages: number; reporting_currency: string }
}
export interface ReferenceData {
  reporting_currency: string
  countries: Country[]
  departments: Department[]
  currencies: { code: string; name: string; has_rate: boolean }[]
  employment_statuses: EmploymentStatus[]
  pay_frequencies: PayFrequency[]
  job_levels: number[]
  low_sample_threshold: number
}
export interface Metrics {
  active_headcount: number
  total_annual_base_reporting: string
  average_annual_base_reporting: string | null
  median_annual_base_reporting: string | null
  low_sample?: boolean
}
export interface AnalyticsSummary {
  reporting_currency: string
  filters: { country: string | null; department: number | null; job_level: number | null }
  organization: Metrics & { status_counts: Record<EmploymentStatus, number> }
  by_country: (Metrics & { country: Country; low_sample: boolean; local_totals: {
    currency: string; active_headcount: number; total_annual_base_local: string
  }[] })[]
  by_department: (Metrics & { department: Department; low_sample: boolean })[]
  notes: string[]
}
export interface RevisionInput {
  amount: string
  currency: string
  pay_frequency: string
  reason: string
  expected_current_salary_record_id: number
}
export interface RevisionResult {
  employee_id: number
  current_salary: SalaryRecord
  previous_salary: SalaryRecord
  reporting_currency: string
}
export type ErrorDetails = Record<string, string[] | string | number>
export interface Envelope<T> { data: T }
