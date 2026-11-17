import type { EmploymentStatus } from '../../types/api'
import { label } from '../../lib/format'
export default function StatusBadge({ status }: { status: EmploymentStatus }) {
  return <span className={`badge status-${status}`}><span aria-hidden="true" className="status-dot" />{label(status)}</span>
}
