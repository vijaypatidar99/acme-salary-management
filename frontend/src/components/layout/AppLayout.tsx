import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { useWriteAccess } from '../../app/write-key-context'

export default function AppLayout() {
  const location = useLocation()
  const access = useWriteAccess()
  return <div className="app-shell">
    <a className="skip-link" href="#main-content">Skip to content</a>
    <aside className="sidebar"><NavLink to="/" className="brand" aria-label="ACME home"><span className="brand-mark">a<span>↗</span></span><span>acme<span className="brand-caption">PEOPLE & PAY</span></span></NavLink>
      <span className="nav-label">WORKSPACE</span><nav aria-label="Main navigation"><NavLink to="/" end><span aria-hidden="true">▦</span>Overview</NavLink><NavLink to="/employees"><span aria-hidden="true">◉</span>Employees</NavLink></nav>
      <div className="sidebar-bottom"><div className="demo-note"><span className="tiny-dot" />Synthetic data only<p>A focused workspace for accurate base-pay decisions.</p></div><NavLink className="health-link" to="/status">API connection ↗</NavLink><div className="workspace-person"><span className="avatar">HR</span><div><strong>HR workspace</strong><small>ACME Salary Management</small></div></div></div>
    </aside>
    <div className="workspace"><header className="topbar"><span>Workspace <span className="crumb-divider">/</span> <strong>{location.pathname === '/' ? 'Compensation' : location.pathname === '/status' ? 'API connection' : 'Employees'}</strong></span><div className="topbar-actions"><span className="demo-pill">Illustrative demo</span>{access.writeKey && <button className="forget-key" onClick={() => access.setWriteKey('')}>Forget write key</button>}</div></header>
      <main id="main-content" className="main-content" tabIndex={-1}><Outlet /></main><footer className="app-footer"><span>ACME · People & pay, made clear.</span><span>Base salary only · Fixed illustrative FX · USD reporting</span></footer>
    </div>
  </div>
}
