import { screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { API_BASE_URL } from '../../lib/api'
import { renderRoute } from '../../test/renderRoute'

describe('StatusPage API status', () => {
  it('calls the health route on the configured API base URL', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 200 }))
    vi.stubGlobal('fetch', fetchMock)

    renderRoute('/status')

    expect(await screen.findByText('reachable')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith(`${API_BASE_URL}/up`, expect.anything())
  })

  it('reports the API as unreachable when the request fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))

    renderRoute('/status')

    expect(await screen.findByText('unreachable')).toBeInTheDocument()
  })

  it('reports the API as unreachable on a non-2xx response', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(null, { status: 500 })))

    renderRoute('/status')

    expect(await screen.findByText('unreachable')).toBeInTheDocument()
  })
})
