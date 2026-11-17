import { Link, useSearchParams } from 'react-router-dom'
import { analyticsFields, queryParams } from '../../lib/api'
import { count, money } from '../../lib/format'
import { useAnalytics, useReferenceData } from '../reference-data/queries'
import { Empty, ErrorPanel, Loading } from '../../components/common/Feedback'
import ReferenceFilters from '../../components/common/ReferenceFilters'

export default function DashboardPage() {
  const [search, setSearch] = useSearchParams()
  const params = queryParams(search, analyticsFields)
  const references = useReferenceData()
  const analytics = useAnalytics(params)
  const data = analytics.data
  const change = (name: string, value: string) => setSearch((previous) => {
    const next = new URLSearchParams(previous)
    if (value) next.set(name, value)
    else next.delete(name)
    return next
  })
  const totalPeople = data ? Object.values(data.organization.status_counts).reduce((total, value) => total + value, 0) : null
  return <>
    <header className="page-heading"><div><span className="eyebrow">The bigger picture</span><h1>Compensation overview</h1><p>A clear view of base pay across your organization.</p></div><Link to="/employees" className="button secondary">Explore employees ↗</Link></header>
    <section className="panel filter-panel" aria-label="Analytics filters"><div className="filter-row">
      <div className="filter-intro"><strong>Choose your perspective</strong><span>Compare a focused group</span></div>
      {references.data && <ReferenceFilters data={references.data} params={params} change={change} analytics />}
      <button className="button quiet" onClick={() => setSearch({})}>Clear filters</button>
    </div>{references.isPending && <Loading text="Loading filter options…" />}{references.isError && <ErrorPanel error={references.error} retry={() => { void references.refetch() }} />}</section>
    {analytics.isPending ? <Loading text="Loading compensation overview…" /> : analytics.isError ? <ErrorPanel error={analytics.error} retry={() => { void analytics.refetch() }} /> : data && <>
      <div className="section-label"><h2>At a glance</h2><span>{count(totalPeople ?? 0)} employees in this selection · Annual reporting in {data.reporting_currency}</span></div>
      <section className="metric-grid" aria-label="Compensation summary">
        <article className="metric-card featured"><span>Total annual base pay</span><strong>{money(data.organization.total_annual_base_reporting, data.reporting_currency)}</strong><small>Active employees · fixed illustrative FX</small></article>
        <article className="metric-card"><span>Active headcount</span><strong>{count(data.organization.active_headcount)}</strong><small>Included in compensation totals</small></article>
        <article className="metric-card"><span>Average annual base pay</span><strong>{money(data.organization.average_annual_base_reporting, data.reporting_currency)}</strong><small>Mean across active employees</small></article>
        <article className="metric-card"><span>Median annual base pay</span><strong>{money(data.organization.median_annual_base_reporting, data.reporting_currency)}</strong><small>Middle of the active pay distribution</small></article>
      </section>
      <div className="population-strip" aria-label="Employment status counts"><span><i className="status-dot status-active" />Active <strong>{count(data.organization.status_counts.active)}</strong></span><span>On leave <strong>{count(data.organization.status_counts.on_leave)}</strong></span><span>Terminated <strong>{count(data.organization.status_counts.terminated)}</strong></span><small>On-leave and terminated employees are excluded from pay totals.</small></div>
      {data.organization.active_headcount === 0 && <Empty title="No active employees in this selection" description="Change the filters to explore compensation for another group." />}
      <section className="panel" aria-labelledby="country-heading"><div className="panel-heading"><div><span className="eyebrow">Geographic perspective</span><h2 id="country-heading">Base pay by country</h2><p>Annual USD values, with original-currency totals.</p></div><span className="pill">{data.by_country.length} countries</span></div>
        <div className="table-scroll" tabIndex={0} role="region" aria-label="Scrollable data table"><table><caption className="sr-only">Country compensation breakdown</caption><thead><tr><th>Country</th><th>Active employees</th><th className="numeric">Annual base · USD</th><th className="numeric">Average · USD</th><th className="numeric">Median · USD</th><th>Local annual totals</th></tr></thead><tbody>{data.by_country.map((row) => <tr key={row.country.code}><td><strong>{row.country.name}</strong><small>{row.country.code} {row.low_sample && <span className="low-sample">Small sample</span>}</small></td><td><strong>{count(row.active_headcount)}</strong><meter aria-label={`${row.country.name} active headcount`} min={0} max={Math.max(1, data.organization.active_headcount)} value={row.active_headcount} /></td><td className="numeric money">{money(row.total_annual_base_reporting)}</td><td className="numeric money">{money(row.average_annual_base_reporting)}</td><td className="numeric money">{money(row.median_annual_base_reporting)}</td><td>{row.local_totals.map((local) => <small className="local-total" key={local.currency}>{money(local.total_annual_base_local, local.currency)} <span>· {count(local.active_headcount)} people</span></small>)}</td></tr>)}</tbody></table></div>
      </section>
      <section className="panel" aria-labelledby="department-heading"><div className="panel-heading"><div><span className="eyebrow">Across the business</span><h2 id="department-heading">Base pay by department</h2><p>Group sizes are shown alongside every comparison.</p></div><span className="pill">{data.by_department.length} departments</span></div><div className="table-scroll" tabIndex={0} role="region" aria-label="Scrollable data table"><table><caption className="sr-only">Department compensation breakdown</caption><thead><tr><th>Department</th><th>Active employees</th><th className="numeric">Annual base · USD</th><th className="numeric">Average · USD</th><th className="numeric">Median · USD</th></tr></thead><tbody>{data.by_department.map((row) => <tr key={row.department.id}><td><strong>{row.department.name}</strong>{row.low_sample && <small className="low-sample">Small sample</small>}</td><td>{count(row.active_headcount)}</td><td className="numeric money">{money(row.total_annual_base_reporting)}</td><td className="numeric money">{money(row.average_annual_base_reporting)}</td><td className="numeric money">{money(row.median_annual_base_reporting)}</td></tr>)}</tbody></table></div></section>
      <aside className="notice insight"><strong>A little context makes a better comparison.</strong><p>Small sample means fewer than {references.data?.low_sample_threshold ?? 'the configured number of'} active employees. Headcount and job-level mix matter. These are descriptive comparisons, not compa-ratios or evidence of pay inequity or attrition risk.</p>{data.notes.map((note) => <p key={note}>{note}</p>)}</aside>
    </>}
  </>
}
