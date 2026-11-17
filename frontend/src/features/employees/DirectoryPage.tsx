import { useEffect, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { api, directoryFields, queryParams } from '../../lib/api'
import { count, date, money } from '../../lib/format'
import { useEmployees, useReferenceData } from '../reference-data/queries'
import { Empty, ErrorPanel, Loading } from '../../components/common/Feedback'
import ReferenceFilters from '../../components/common/ReferenceFilters'
import StatusBadge from '../../components/common/StatusBadge'

const sorts = { employee_number: 'Employee ID', name: 'Name', country: 'Country', department: 'Department', job_level: 'Job level', hired_on: 'Hire date', status: 'Employment status', annual_base_reporting: 'Annual base pay · USD' }
function SearchBox({ value, reset, search }: { value: string; reset: number; search: (value: string) => void }) {
  const [state, setState] = useState({ url: value, reset, draft: value })
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const latestSearch = useRef(search)
  useEffect(() => { latestSearch.current = search }, [search])
  // Synchronize actual search/back/clear changes, while retaining a draft on filter/page changes.
  if (state.url !== value || state.reset !== reset) setState({ url: value, reset, draft: value })
  useEffect(() => () => clearTimeout(timer.current), [value, reset])
  return <label className="search-label">Search employees<input type="search" placeholder="Search by name or employee ID" value={state.draft} maxLength={100} onChange={(e) => {
    const draft = e.target.value
    setState((previous) => ({ ...previous, draft }))
    clearTimeout(timer.current)
    // Use current URL state if a filter/page changed while this draft was pending.
    timer.current = setTimeout(() => latestSearch.current(draft.trim()), 300)
  }} /></label>
}

export default function DirectoryPage() {
  const [search, setSearch] = useSearchParams()
  const [reset, setReset] = useState(0)
  const params = queryParams(search, directoryFields)
  const references = useReferenceData()
  const employees = useEmployees(params)
  const change = (name: string, value: string) => setSearch((previous) => {
    const next = new URLSearchParams(previous)
    if (value) next.set(name, value)
    else next.delete(name)
    if (name !== 'page') next.delete('page')
    return next
  })
  const clear = () => { setSearch({}); setReset((value) => value + 1) }
  const result = employees.data
  return <>
    <header className="page-heading"><div><span className="eyebrow">People & compensation</span><h1>Employee directory</h1><p>Find a person. Understand their pay. Keep every change.</p></div><a className="button primary" href={api.exportUrl(params)}>↓ Export CSV</a></header>
    <section className="panel filter-panel" aria-label="Employee filters">
      <div className="filter-row"><SearchBox value={params.q ?? ''} reset={reset} search={(value) => change('q', value)} />
        {references.data && <ReferenceFilters data={references.data} params={params} change={change} />}
        <button className="button quiet" onClick={clear}>Clear filters</button></div>
      {references.isPending && <Loading text="Loading filter options…" />}
      {references.isError && <ErrorPanel error={references.error} retry={() => { void references.refetch() }} />}
    </section>
    <section className="panel" aria-label="Employee results">
      <div className="panel-heading"><div><h2>All employees</h2><p>{result ? `${count(result.meta.total_count)} matching employees` : 'Compensation records'}</p></div><div className="table-controls">
        <label>Sort by<select value={params.sort ?? 'employee_number'} onChange={(e) => change('sort', e.target.value)}>{Object.entries(sorts).map(([value, name]) => <option key={value} value={value}>{name}</option>)}</select></label>
        <label>Direction<select value={params.direction ?? 'asc'} onChange={(e) => change('direction', e.target.value)}><option value="asc">Ascending</option><option value="desc">Descending</option></select></label>
      </div></div>
      {employees.isPending ? <Loading /> : employees.isError ? <ErrorPanel error={employees.error} retry={() => { void employees.refetch() }} /> : result && <>
        {result.data.length === 0 ? <Empty title="No employees on this page" description="Try another search or filter, or return to the first page." /> : <div className="table-scroll" tabIndex={0} role="region" aria-label="Scrollable data table"><table><caption className="sr-only">Employee directory, ordered by the selected sort</caption><thead><tr><th>Employee</th><th>Department / level</th><th>Country</th><th>Status</th><th>Base salary</th><th className="numeric">Annual base · USD</th></tr></thead><tbody>{result.data.map((employee) => <tr key={employee.id}>
          <td><Link className="person-link" to={`/employees/${employee.id}`} state={{ directorySearch: search.toString() }}><span className="avatar" aria-hidden="true">{employee.first_name[0]}{employee.last_name[0]}</span><span><strong>{employee.first_name} {employee.last_name}</strong><small>{employee.employee_number}</small></span></Link></td>
          <td><strong>{employee.department.name}</strong><small>{employee.job_title} · L{employee.job_level}</small></td><td>{employee.country.name}<small>Hired {date(employee.hired_on)}</small></td><td><StatusBadge status={employee.employment_status} /></td>
          <td>{employee.current_salary ? <><span className="money">{money(employee.current_salary.amount, employee.current_salary.currency)}</span><small>{employee.current_salary.pay_frequency}{employee.employment_status === 'terminated' ? ' · last held' : ''}</small></> : 'Not available'}</td>
          <td className="numeric money">{money(employee.current_salary?.annual_base_reporting ?? null)}</td>
        </tr>)}</tbody></table></div>}
        <div className="pagination"><span>{result.meta.total_pages > 0 && <>Page {count(result.meta.page)} of {count(result.meta.total_pages)} · </>}{count(result.meta.total_count)} employees</span><div className="pagination-actions">
          <label>Rows per page<select value={params.per_page ?? '25'} onChange={(e) => change('per_page', e.target.value)}>{[10, 25, 50, 100].map((size) => <option key={size} value={size}>{size}</option>)}</select></label>
          <button className="button secondary" disabled={result.meta.page <= 1} onClick={() => change('page', String(Math.max(1, result.meta.page - 1)))}>Previous</button>
          <button className="button secondary" disabled={result.meta.page >= result.meta.total_pages} onClick={() => change('page', String(result.meta.page + 1))}>Next</button>
          {result.meta.page > result.meta.total_pages && <button className="button quiet" onClick={() => change('page', '1')}>First page</button>}
        </div></div>
      </>}
    </section>
    <p className="footnote">Export includes all matching rows, with the same filters and sort. To reconcile with the dashboard, use active employees and the same country/department filters, without search or a dashboard level filter.</p>
  </>
}
