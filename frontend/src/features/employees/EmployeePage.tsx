import { Link, useLocation, useParams } from 'react-router-dom'
import { useEmployee } from '../reference-data/queries'
import { useWriteAccess } from '../../app/write-key-context'
import { date, money, timestamp } from '../../lib/format'
import { Empty, ErrorPanel, Loading } from '../../components/common/Feedback'
import StatusBadge from '../../components/common/StatusBadge'

export default function EmployeePage() {
  const { id = '' } = useParams()
  const query = useEmployee(id)
  const location = useLocation()
  const { writesDisabled } = useWriteAccess()
  const directorySearch = (location.state as { directorySearch?: string } | null)?.directorySearch
  const back = `/employees${directorySearch ? `?${directorySearch}` : ''}`
  const employee = query.data
  return <>
    <Link className="back-link" to={back}>← Back to employees</Link>
    {query.isPending ? <Loading text="Loading employee profile…" /> : query.isError ? <ErrorPanel error={query.error} retry={() => { void query.refetch() }} /> : employee && <>
      <header className="page-heading profile-heading"><div className="profile-person"><span className="avatar large" aria-hidden="true">{employee.first_name[0]}{employee.last_name[0]}</span><div><span className="eyebrow">{employee.employee_number}</span><h1>{employee.first_name} {employee.last_name}</h1><p>{employee.job_title} · {employee.department.name}</p></div></div><StatusBadge status={employee.employment_status} /></header>
      {(location.state as { revised?: boolean } | null)?.revised && <div role="status" className="notice success"><strong>Salary revision saved.</strong><p>The confirmed salary and complete history are shown below.</p></div>}
      <section className="profile-grid"><article className="panel profile-info"><div className="panel-heading"><h2>Employee details</h2></div><dl className="facts"><div><dt>Country</dt><dd>{employee.country.name}</dd></div><div><dt>Department</dt><dd>{employee.department.name}</dd></div><div><dt>Job level</dt><dd>Level {employee.job_level}</dd></div><div><dt>Hired</dt><dd>{date(employee.hired_on)}</dd></div>{employee.terminated_on && <div><dt>Terminated</dt><dd>{date(employee.terminated_on)}</dd></div>}</dl></article>
      <article className="panel compensation-card"><div className="panel-heading"><div><span className="eyebrow">Base compensation</span><h2>{employee.employment_status === 'terminated' ? 'Last salary held' : 'Current salary'}</h2></div>{employee.can_revise_salary && !writesDisabled && employee.current_salary && <Link className="button primary" to={`/employees/${employee.id}/revise`} state={{ directorySearch }}>Revise salary ↗</Link>}</div>
        {employee.current_salary ? <><div className="salary-hero"><strong>{money(employee.current_salary.amount, employee.current_salary.currency)}</strong><span>per {employee.current_salary.pay_frequency === 'monthly' ? 'month' : 'year'}</span></div><dl className="facts"><div><dt>Annual base · local</dt><dd className="money">{money(employee.current_salary.annual_base_local, employee.current_salary.currency)}</dd></div><div><dt>Annual base · USD</dt><dd className="money">{money(employee.current_salary.annual_base_reporting)}</dd></div><div><dt>Effective from</dt><dd>{timestamp(employee.current_salary.effective_from)}</dd></div></dl></> : <p className="panel-body">No salary record is available.</p>}
        {employee.employment_status === 'terminated' && <p className="card-note">Retained for history. This salary is excluded from active compensation totals and cannot be revised.</p>}
        {employee.employment_status === 'on_leave' && <p className="card-note">Salary revisions are allowed while on leave. This employee is excluded from active compensation totals.</p>}
        {writesDisabled && <p className="card-note">Editing is disabled on this server.</p>}
      </article></section>
      <section className="panel" aria-labelledby="history-heading"><div className="panel-heading"><div><span className="eyebrow">Every change, preserved</span><h2 id="history-heading">Salary history</h2><p>Newest first · Effective times in UTC · Read-only records</p></div><span className="pill">{employee.salary_history.length} records</span></div>
        {employee.salary_history.length === 0 ? <Empty title="No salary history" description="No salary records are available for this employee." /> : <div className="table-scroll" tabIndex={0} role="region" aria-label="Scrollable data table"><table><caption className="sr-only">Complete salary history, newest first</caption><thead><tr><th>Salary / frequency</th><th>Annual base</th><th>FX snapshot</th><th>Effective interval · UTC</th><th>Reason</th><th>Record</th></tr></thead><tbody>{employee.salary_history.map((record) => <tr key={record.id}><td><strong className="money">{money(record.amount, record.currency)}</strong><small>{record.pay_frequency}</small></td><td><span className="money">{money(record.annual_base_reporting)}</span><small>{money(record.annual_base_local, record.currency)} local</small></td><td><span className="money">{record.fx_rate}</span><small>USD per 1 {record.currency}</small></td><td className="interval"><time dateTime={record.effective_from}>{timestamp(record.effective_from)}</time><small>to {record.effective_to ? <time dateTime={record.effective_to}>{timestamp(record.effective_to)}</time> : 'Open-ended'}</small></td><td className="reason-cell">{record.reason}</td><td><span className={`badge ${record.is_current ? 'status-active' : ''}`}>{record.is_current ? employee.employment_status === 'terminated' ? 'Last held' : 'Current' : 'Historical'}</span></td></tr>)}</tbody></table></div>}
      </section><p className="footnote">USD amounts use fixed illustrative FX snapshots. They are not live exchange rates. History records show inclusive starts and exclusive ends.</p>
    </>}
  </>
}
