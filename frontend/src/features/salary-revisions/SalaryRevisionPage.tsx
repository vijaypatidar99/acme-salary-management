import { useRef, useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { api, ApiError } from '../../lib/api'
import { money, timestamp } from '../../lib/format'
import { useEmployee, useReferenceData } from '../reference-data/queries'
import { useWriteAccess } from '../../app/write-key-context'
import { ErrorPanel, Loading } from '../../components/common/Feedback'
import type { EmployeeDetail, ReferenceData } from '../../types/api'

// Ruby String#strip removes these ASCII characters; count code points as Ruby String#length does.
const rubyWhitespace = (char: string) => char === ' ' || '\0\t\n\v\f\r'.includes(char)
const trimReason = (value: string) => {
  const chars = [...value]
  while (chars.length && rubyWhitespace(chars[0])) chars.shift()
  while (chars.length && rubyWhitespace(chars[chars.length - 1])) chars.pop()
  return chars.join('')
}
type Fields = Record<string, string>
function inputErrors(amount: string, reason: string, currency: string, frequency: string, key: string): Fields {
  const errors: Fields = {}
  // String syntax checks only. No decimal conversion, arithmetic or salary comparisons.
  if (!/^(0|[1-9][0-9]*)(\.[0-9]{1,2})?$/.test(amount)) errors.amount = 'Enter a decimal amount with at most two decimal places, without commas or spaces.'
  else if (/^0(?:\.0{1,2})?$/.test(amount)) errors.amount = 'Amount must be greater than zero.'
  else if (!/^(?:(?:0|[1-9][0-9]{0,8})(?:\.[0-9]{1,2})?|1000000000(?:\.0{1,2})?)$/.test(amount)) errors.amount = 'The maximum entered amount is 1,000,000,000.00 in the selected currency and pay period.'
  if (!trimReason(reason)) errors.reason = 'Enter a revision reason.'
  else if ([...trimReason(reason)].length > 255) errors.reason = 'Use 255 characters or fewer.'
  if (!currency) errors.currency = 'Choose a currency with an available FX rate.'
  if (!frequency) errors.pay_frequency = 'Choose a pay frequency.'
  if (!key) errors.write_key = 'Enter the demo write key to authorize this revision.'
  return errors
}
function RevisionForm({ employee, references, directorySearch }: { employee: EmployeeDetail; references: ReferenceData; directorySearch?: string }) {
  const salary = employee.current_salary!
  const navigate = useNavigate()
  const client = useQueryClient()
  const access = useWriteAccess()
  const [amount, setAmount] = useState(salary.amount)
  const [currency, setCurrency] = useState(references.currencies.some((item) => item.code === salary.currency && item.has_rate) ? salary.currency : '')
  const [frequency, setFrequency] = useState<string>(salary.pay_frequency)
  const [reason, setReason] = useState('')
  const [token, setToken] = useState(salary.id)
  const [errors, setErrors] = useState<Fields>({})
  const [message, setMessage] = useState('')
  const [conflict, setConflict] = useState(false)
  const sending = useRef(false)
  const mutation = useMutation({
    mutationFn: () => api.revise(employee.id, { amount, currency, pay_frequency: frequency, reason: trimReason(reason), expected_current_salary_record_id: token }, access.writeKey),
    retry: false,
    onSuccess: async ({ data }) => {
      client.setQueryData<EmployeeDetail>(['employee', String(employee.id)], (old) => old ? {
        ...old, current_salary: data.current_salary,
        salary_history: [data.current_salary, ...old.salary_history.map((record) => record.id === data.previous_salary.id ? data.previous_salary : record)],
      } : old)
      await Promise.all([
        client.invalidateQueries({ queryKey: ['employee', String(employee.id)] }),
        client.invalidateQueries({ queryKey: ['employees'] }),
        client.invalidateQueries({ queryKey: ['analytics'] }),
      ])
      navigate(`/employees/${employee.id}`, { replace: true, state: { revised: true, directorySearch } })
    },
    onError: async (error) => {
      if (!(error instanceof ApiError)) { setMessage('The revision could not be confirmed. Reload the employee before trying again.'); return }
      switch (error.code) {
        case 'unauthorized': access.setWriteKey(''); setMessage('The write key was not accepted. Enter it again to continue.'); break
        case 'writes_disabled': access.disableWrites(); break
        case 'stale_salary_record':
          setConflict(true)
          setMessage('This salary changed while you were editing. The latest salary is shown above. Review it before submitting a new revision.')
          await client.invalidateQueries({ queryKey: ['employee', String(employee.id)] })
          break
        case 'revision_conflict': setMessage('The revision conflicts with the salary history. Reload the employee and try again.'); break
        case 'employee_not_eligible':
          setMessage('This employee is no longer eligible for salary revisions.')
          await client.invalidateQueries({ queryKey: ['employee', String(employee.id)] })
          break
        case 'no_change': setMessage('Amount, currency and pay frequency are unchanged. A reason-only edit is not a salary revision.'); break
        case 'missing_exchange_rate': setMessage('No applicable FX rate is available for this currency. Choose another currency; no salary was changed.'); break
        case 'validation_failed': {
          const next: Fields = {}
          for (const name of ['amount', 'currency', 'pay_frequency', 'reason']) {
            const detail = error.details[name]
            if (Array.isArray(detail)) next[name] = detail.join('. ')
          }
          setErrors(next)
          setMessage('Review the highlighted fields. The revision was not saved.')
          break
        }
        case 'not_found': setMessage('This employee could not be found. Return to the directory.'); break
        case 'invalid_request': setMessage('The server could not accept this request. Reload the employee before trying again.'); break
        default: setMessage('We could not confirm the revision. Reload the employee to check its current salary before trying again.')
      }
    },
    onSettled: () => { sending.current = false },
  })
  const submit = (event: FormEvent) => {
    event.preventDefault()
    if (sending.current || mutation.isPending || conflict) return
    const next = inputErrors(amount, reason, currency, frequency, access.writeKey)
    setErrors(next)
    setMessage('')
    if (Object.keys(next).length) { setMessage('Review the form before saving.'); return }
    sending.current = true
    mutation.mutate()
  }
  const fieldError = (name: string) => errors[name] ? <small className="field-error" id={`${name}-error`}>{errors[name]}</small> : null
  if (access.writesDisabled) return <div className="notice error" role="alert"><strong>Editing is disabled on this server.</strong><p>No write key is configured. You can still browse employee records and history.</p><Link to={`/employees/${employee.id}`} state={{ directorySearch }}>Return to employee</Link></div>
  return <form className="panel revision-form" onSubmit={submit} noValidate>
    <div className="panel-heading"><div><span className="eyebrow">A new chapter in the record</span><h2>New base salary</h2><p>Changes take effect immediately. Previous records are preserved.</p></div></div>
    <div className="form-body">
      {message && <div className="notice error" role="alert"><p>{message}</p>{conflict && <button type="button" className="button secondary" disabled={salary.id === token} onClick={() => {
        setAmount(salary.amount); setCurrency(salary.currency); setFrequency(salary.pay_frequency); setToken(salary.id); setConflict(false); setMessage(''); setErrors({})
      }}>Review latest salary and reset form</button>}{conflict && salary.id === token && <Link to={`/employees/${employee.id}`} state={{ directorySearch }}>Reload employee profile</Link>}</div>}
      <fieldset disabled={mutation.isPending || conflict}><legend className="sr-only">Salary revision fields</legend><div className="form-grid">
        <label>New salary amount<input autoFocus inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} aria-invalid={!!errors.amount} aria-describedby="amount-help amount-error" required /><small id="amount-help">Enter the amount per pay period, up to 1,000,000,000.00.</small>{fieldError('amount')}</label>
        <label>Currency<select value={currency} onChange={(e) => setCurrency(e.target.value)} aria-invalid={!!errors.currency} aria-describedby="currency-error" required><option value="">Choose currency</option>{references.currencies.filter((item) => item.has_rate).map((item) => <option key={item.code} value={item.code}>{item.code} · {item.name}</option>)}</select>{fieldError('currency')}</label>
        <label>Pay frequency<select value={frequency} onChange={(e) => setFrequency(e.target.value)} aria-invalid={!!errors.pay_frequency} aria-describedby="pay_frequency-error" required><option value="">Choose frequency</option>{references.pay_frequencies.map((item) => <option key={item} value={item}>{item === 'monthly' ? 'Monthly' : 'Annual'}</option>)}</select>{fieldError('pay_frequency')}</label>
        <label className="full-width">Revision reason<textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} aria-invalid={!!errors.reason} aria-describedby="reason-help reason-error" required /><small id="reason-help">Required · 1–255 characters after trimming.</small>{fieldError('reason')}</label>
      </div>
      <div className="write-key-box"><div><strong>Authorize this change</strong><p>Your demo write key is held in memory for this tab. It is cleared on reload or an invalid-key response.</p></div><label>Demo write key<input type="password" autoComplete="off" value={access.writeKey} onChange={(e) => access.setWriteKey(e.target.value)} aria-invalid={!!errors.write_key} aria-describedby="write_key-error" required />{fieldError('write_key')}</label></div>
      </fieldset>
      <div className="form-actions"><Link className="button secondary" aria-disabled={mutation.isPending} onClick={(event) => { if (mutation.isPending) event.preventDefault() }} to={`/employees/${employee.id}`} state={{ directorySearch }}>Cancel</Link><button type="submit" className="button primary" disabled={mutation.isPending || conflict}>{mutation.isPending ? 'Saving revision…' : 'Save salary revision'}</button></div>
    </div>
  </form>
}
export default function SalaryRevisionPage() {
  const { id = '' } = useParams()
  const location = useLocation()
  const directorySearch = (location.state as { directorySearch?: string } | null)?.directorySearch
  const employee = useEmployee(id)
  const references = useReferenceData()
  const current = employee.data
  return <>
    <Link className="back-link" to={`/employees/${encodeURIComponent(id)}`} state={{ directorySearch }}>← Back to employee</Link>
    <header className="page-heading"><div><span className="eyebrow">Compensation management</span><h1>Revise salary</h1><p>A deliberate change. A complete history.</p></div></header>
    {employee.isPending ? <Loading text="Loading current salary…" /> : employee.isError ? <ErrorPanel error={employee.error} retry={() => { void employee.refetch() }} /> : current && <>
      <section className="current-salary-banner" aria-label="Current compensation"><div><span className="eyebrow">{current.employee_number} · {current.employment_status === 'terminated' ? 'Last salary held' : 'Current salary'}</span><h2>{current.first_name} {current.last_name}</h2></div>{current.current_salary && <div><strong className="money">{money(current.current_salary.amount, current.current_salary.currency)} / {current.current_salary.pay_frequency === 'monthly' ? 'month' : 'year'}</strong><small>Since {timestamp(current.current_salary.effective_from)}</small></div>}</section>
      {!current.can_revise_salary ? <div className="notice" role="status">This employee is not eligible for salary revisions. Retained salary history remains available on the profile.</div>
        : !current.current_salary ? <div className="notice error" role="alert">No current salary record is available. A revision cannot be created.</div>
        : references.isPending ? <Loading text="Loading revision options…" /> : references.isError ? <ErrorPanel error={references.error} retry={() => { void references.refetch() }} />
        : references.data && <RevisionForm employee={current} references={references.data} directorySearch={directorySearch} />}
    </>}
  </>
}
