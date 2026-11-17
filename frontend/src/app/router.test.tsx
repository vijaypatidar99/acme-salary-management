import { screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { renderRoute } from '../test/renderRoute'

describe('routes', () => {
  it('renders the home page at /', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(null, { status: 200 })))

    renderRoute('/')

    expect(screen.getByRole('heading', { name: 'ACME Salary Management' })).toBeInTheDocument()
    expect(await screen.findByText('reachable')).toBeInTheDocument()
  })

  it('renders the not-found page for an unknown path', () => {
    renderRoute('/no/such/page')

    expect(screen.getByRole('heading', { name: 'Page not found' })).toBeInTheDocument()
  })
})
