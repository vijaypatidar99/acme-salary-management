import { describe, expect, it, vi } from 'vitest'
import { api, ApiError } from './api'
import { apiFailure, employee, jsonResponse, mockApi } from '../test/fixtures'

describe('API boundary', () => {
  it('whitelists export filters and keeps paging, write keys and unsupported fields out', () => {
    const url = new URL(api.exportUrl({ q: 'Asha & Rao', country: 'IN', sort: 'name', direction: 'desc', page: '2', per_page: '25', write_key: 'not-sent', job_level: '4' }))
    expect(Object.fromEntries(url.searchParams)).toEqual({ q: 'Asha & Rao', country: 'IN', sort: 'name', direction: 'desc' })
  })
  it('keeps money strings and sends the write key on the revision POST only', async () => {
    const fetch = mockApi((url) => url.pathname.endsWith('/salary_revisions') ? jsonResponse({ data: {} }, 201) : undefined)
    expect((await api.employee('42')).data.current_salary?.amount).toBe('250000.00')
    await api.revise(42, { amount: '270000.00', currency: 'INR', pay_frequency: 'monthly', reason: 'Review', expected_current_salary_record_id: 9001 }, 'test-memory-key')
    expect((fetch.mock.calls[0][1]?.headers as Record<string, string>).Authorization).toBeUndefined()
    expect((fetch.mock.calls[1][1]?.headers as Record<string, string>).Authorization).toBe('Bearer test-memory-key')
    expect(JSON.parse(fetch.mock.calls[1][1]!.body as string).salary_revision.amount).toBe('270000.00')
  })
  it('preserves API error codes and details, without exposing server messages', async () => {
    mockApi(() => apiFailure(422, 'validation_failed', { amount: ['is invalid'] }))
    await expect(api.employee('42')).rejects.toMatchObject({ status: 422, code: 'validation_failed', details: { amount: ['is invalid'] } })
  })
  it('reports network and malformed responses', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('network internal detail')))
    await expect(api.employee('42')).rejects.toEqual(new ApiError(0, 'network_error'))
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('not JSON')))
    await expect(api.employee('42')).rejects.toMatchObject({ code: 'invalid_response' })
  })
  it('encodes path IDs without generating new endpoints', async () => {
    const fetch = mockApi(() => jsonResponse({ data: employee }))
    await api.employee('42/other')
    expect(String(fetch.mock.calls[0][0])).toContain('/employees/42%2Fother')
  })
})
