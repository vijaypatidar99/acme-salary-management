import { ApiError } from '../../lib/api'
export function Loading({ text = 'Loading records…' }: { text?: string }) {
  return <div className="loading-panel" role="status"><span className="loading-dot" />{text}</div>
}
export function ErrorPanel({ error, retry }: { error: unknown; retry?: () => void }) {
  const message = error instanceof ApiError && error.status === 404 ? 'This employee could not be found.'
    : error instanceof ApiError && error.status === 400 ? 'These filters are not valid. Clear the filters and try again.'
    : 'We could not load this information. Check the API connection and try again.'
  return <div className="notice error" role="alert"><strong>Something needs attention</strong><p>{message}</p>{retry && <button className="button secondary" onClick={retry}>Try again</button>}</div>
}
export function Empty({ title, description }: { title: string; description: string }) {
  return <div className="empty-panel"><span className="empty-symbol" aria-hidden="true">↗</span><h2>{title}</h2><p>{description}</p></div>
}
