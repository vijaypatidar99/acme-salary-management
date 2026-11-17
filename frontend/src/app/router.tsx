import { createBrowserRouter, type RouteObject } from 'react-router-dom'
import AppLayout from '../components/layout/AppLayout'
import NotFoundPage from '../components/common/NotFoundPage'
import StatusPage from '../features/health/StatusPage'
import DashboardPage from '../features/dashboard/DashboardPage'
import DirectoryPage from '../features/employees/DirectoryPage'
import EmployeePage from '../features/employees/EmployeePage'
import SalaryRevisionPage from '../features/salary-revisions/SalaryRevisionPage'

export const routes: RouteObject[] = [{
  element: <AppLayout />,
  children: [
    { index: true, element: <DashboardPage /> },
    { path: 'employees', element: <DirectoryPage /> },
    { path: 'employees/:id', element: <EmployeePage /> },
    { path: 'employees/:id/revise', element: <SalaryRevisionPage /> },
    { path: 'status', element: <StatusPage /> },
    { path: '*', element: <NotFoundPage /> },
  ],
}]
export const createAppRouter = () => createBrowserRouter(routes)
