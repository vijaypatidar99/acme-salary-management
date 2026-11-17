import { QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router-dom'
import { createQueryClient } from '../lib/query-client'
import { routes } from '../app/router'
import WriteKeyProvider from '../app/WriteKeyProvider'

// Mounts the real routes at `path` with an isolated query cache.
export function renderRoute(path: string) {
  const router = createMemoryRouter(routes, { initialEntries: [path] })
  const client = createQueryClient()
  client.setDefaultOptions({ queries: { retry: false, gcTime: 0 }, mutations: { retry: false } })
  const view = render(
    <QueryClientProvider client={client}>
      <WriteKeyProvider><RouterProvider router={router} /></WriteKeyProvider>
    </QueryClientProvider>,
  )
  return { ...view, router, client }
}
