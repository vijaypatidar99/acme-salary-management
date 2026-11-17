// Display only: decimal strings never pass through Number, parseFloat, arithmetic or rounding.
export function money(value: string | null, currency = 'USD'): string {
  if (value === null) return '—'
  const [whole, fraction] = value.split('.')
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  return `${currency} ${grouped}${fraction === undefined ? '' : `.${fraction}`}`
}
export const count = (value: number) => new Intl.NumberFormat('en-US').format(value)
export const label = (value: string) => value.replaceAll('_', ' ').replace(/^./, (char) => char.toUpperCase())
export function date(value: string | null): string {
  return value ? new Intl.DateTimeFormat('en-GB', { dateStyle: 'medium', timeZone: 'UTC' }).format(new Date(`${value}T00:00:00Z`)) : '—'
}
// Preserve microseconds; Date would silently discard digits beyond milliseconds.
export const timestamp = (value: string | null) => value ? value.replace('T', ' · ').replace('Z', ' UTC') : 'Open-ended'
