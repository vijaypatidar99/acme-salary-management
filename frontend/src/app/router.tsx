import { createBrowserRouter, type RouteObject } from 'react-router-dom'
import AppLayout from '../components/layout/AppLayout'
import NotFoundPage from '../components/common/NotFoundPage'
import StatusPage from '../features/health/StatusPage'

// Exported separately from the router so tests can mount the same routes in a memory router.
export const routes: RouteObject[] = [
  {
    element: <AppLayout />,
    children: [
      { index: true, element: <StatusPage /> },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
]

export const createAppRouter = () => createBrowserRouter(routes)
