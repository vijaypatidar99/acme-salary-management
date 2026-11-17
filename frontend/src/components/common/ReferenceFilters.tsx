import type { ReferenceData } from '../../types/api'
export default function ReferenceFilters({ data, params, change, analytics = false }: {
  data: ReferenceData; params: Record<string, string>; change: (name: string, value: string) => void; analytics?: boolean
}) {
  return <>
    <label>Country<select value={params.country ?? ''} onChange={(e) => change('country', e.target.value)}><option value="">All countries</option>{data.countries.map((c) => <option key={c.code} value={c.code}>{c.name}</option>)}</select></label>
    <label>Department<select value={params.department ?? ''} onChange={(e) => change('department', e.target.value)}><option value="">All departments</option>{data.departments.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}</select></label>
    {analytics ? <label>Job level<select value={params.job_level ?? ''} onChange={(e) => change('job_level', e.target.value)}><option value="">All levels</option>{data.job_levels.map((level) => <option key={level} value={level}>Level {level}</option>)}</select></label>
      : <label>Employment status<select value={params.status ?? ''} onChange={(e) => change('status', e.target.value)}><option value="">All statuses</option>{data.employment_statuses.map((status) => <option key={status} value={status}>{status.replaceAll('_', ' ')}</option>)}</select></label>}
  </>
}
