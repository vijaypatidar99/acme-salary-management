import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from 'react-router-dom'
import { createQueryClient } from '../lib/query-client'
import { createAppRouter } from './router'
import WriteKeyProvider from './WriteKeyProvider'

const queryClient = createQueryClient()
const router = createAppRouter()

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <WriteKeyProvider><RouterProvider router={router} /></WriteKeyProvider>
    </QueryClientProvider>
  )
}
