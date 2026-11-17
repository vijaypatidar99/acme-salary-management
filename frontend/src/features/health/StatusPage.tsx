import { useApiHealth } from './useApiHealth'

// Temporary landing page: it proves the SPA reaches the API. Replaced by the directory.
export default function StatusPage() {
  const { isPending, isError } = useApiHealth()
  const status = isPending ? 'checking…' : isError ? 'unreachable' : 'reachable'

  return (
    <section>
      <h1 className="text-2xl font-semibold">ACME Salary Management</h1>
      <p className="mt-2 text-slate-600">
        API status: <span role="status">{status}</span>
      </p>
    </section>
  )
}
