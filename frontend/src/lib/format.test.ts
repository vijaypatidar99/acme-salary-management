import { describe, expect, it } from 'vitest'
import { money, timestamp, date } from './format'

describe('display formatting', () => {
  it('keeps decimal strings exact, including amounts beyond Number precision', () => {
    expect(money('12345678901234567890.01')).toBe('USD 12,345,678,901,234,567,890.01')
    expect(money('0.00', 'INR')).toBe('INR 0.00')
    expect(money(null)).toBe('—')
    expect(money('85000.10')).toBe('USD 85,000.10')
  })
  it('preserves UTC microseconds and date-only values', () => {
    expect(timestamp('2026-11-17T09:30:00.123456Z')).toBe('2026-11-17 · 09:30:00.123456 UTC')
    expect(timestamp(null)).toBe('Open-ended')
    expect(date('2019-04-01')).toBe('1 Apr 2019')
  })
})
