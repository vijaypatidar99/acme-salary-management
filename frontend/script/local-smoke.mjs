// Native CDP smoke checks. Start isolated Chrome as documented in docs/local-browser-smoke.md.
// No npm/browser dependency. Writes require explicit opt-in AND the special disposable fixture.
import fs from 'node:fs/promises'
const frontend = process.env.QA_FRONTEND_ORIGIN ?? 'http://127.0.0.1:5173'
const api = process.env.QA_API_ORIGIN ?? 'http://127.0.0.1:3000'
const cdp = process.env.QA_CDP_ORIGIN ?? 'http://127.0.0.1:9232'
const writes = process.env.QA_DISPOSABLE_WRITES === '1'
for (const origin of [frontend, api, cdp]) {
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(origin).hostname)) throw new Error('Local origins only')
}
const get = async (path) => {
  const response = await fetch(`${api}/api/v1${path}`)
  if (!response.ok) throw new Error(`Read failed: ${response.status}`)
  return response.json()
}
let fixture
if (writes) {
  if (!process.env.ACME_TEST_DATABASE || !process.env.QA_WRITE_KEY) throw new Error('Source the attested disposable environment and set QA_WRITE_KEY first')
  fixture = (await get('/employees/10001')).data
  if (fixture.employee_number !== 'QA-LOCAL-10001' || fixture.first_name !== 'Local QA' || fixture.salary_history.length < 1000) throw new Error('Disposable fixture identity missing; refusing writes')
}
const targets = await (await fetch(`${cdp}/json/list`)).json()
const socket = new WebSocket(targets.find((target) => target.type === 'page').webSocketDebuggerUrl)
await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }) })
let id = 0
const pending = new Map(), errors = [], checks = [], requests = []
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data)
  if (message.id) {
    const request = pending.get(message.id); pending.delete(message.id)
    if (message.error) request.reject(new Error(message.error.message)); else request.resolve(message.result)
  } else if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails.text)
  else if (message.method === 'Network.requestWillBeSent' && message.params.request.url.includes('/api/v1/')) {
    const request = message.params.request
    if (request.method === 'GET' && Object.keys(request.headers).some((key) => key.toLowerCase() === 'authorization')) errors.push('Authorization sent on GET')
    requests.push({ method: request.method, url: request.url }) // Never record headers or request bodies.
  }
})
const call = (method, params = {}) => new Promise((resolve, reject) => { const request = ++id; pending.set(request, { resolve, reject }); socket.send(JSON.stringify({ id: request, method, params })) })
const evaluate = async (expression) => (await call('Runtime.evaluate', { expression, returnByValue: true })).result.value
const wait = async (expression) => {
  for (let attempt = 0; attempt < 200; attempt++) {
    if (await evaluate(expression)) return
    await new Promise((resolve) => setTimeout(resolve, 100))
  }
  throw new Error(`UI condition timed out: ${expression}`)
}
const assert = (condition, text) => { if (!condition) throw new Error(text); checks.push(text) }
const go = async (path) => { await call('Page.navigate', { url: frontend + path }) }
const click = async (expression) => evaluate(`${expression}.click()`)
const input = async (selector, value) => {
  await evaluate(`(() => { const element = document.querySelector(${JSON.stringify(selector)}); element.focus(); element.select(); })()`)
  await call('Input.insertText', { text: value })
}
try {
  await call('Page.enable'); await call('Runtime.enable'); await call('Network.enable')
  await go('/'); await wait("document.body.innerText.includes('Total annual base pay') && document.body.innerText.includes('Base pay by country')")
  checks.push('Dashboard statistics and distributions load from Rails')
  await go('/employees'); await wait("document.body.innerText.includes('matching employees') && !!document.querySelector('input[type=search]')")
  await input('input[type=search]', 'ACME-0000')
  await wait("location.search.includes('q=ACME-0000') && document.body.innerText.includes('matching employees')")
  assert(await evaluate("document.activeElement === document.querySelector('input[type=search]')"), 'Search keeps focus after debounce')
  await call('Input.insertText', { text: '1' })
  await wait("location.search.includes('q=ACME-00001') && document.body.innerText.includes('1 matching employees')")
  assert(await evaluate("document.activeElement === document.querySelector('input[type=search]')"), 'Typing continues after a debounce pause')
  await click("[...document.querySelectorAll('button')].find(e => e.textContent === 'Clear filters')")
  await wait("!location.search && document.querySelector('input[type=search]').value === '' && !![...document.querySelectorAll('button')].find(e => e.textContent === 'Next')")
  await click("[...document.querySelectorAll('button')].find(e => e.textContent === 'Next')")
  await wait("location.search.includes('page=2') && document.body.innerText.includes('Page 2 of')")
  await evaluate("(() => { const select = [...document.querySelectorAll('label')].find(e => e.textContent.startsWith('Country')).querySelector('select'); select.value = 'IN'; select.dispatchEvent(new Event('change', { bubbles: true })); })()")
  await wait("location.search.includes('country=IN') && !location.search.includes('page=')")
  checks.push('Clear, pagination, country filter and page reset work')
  await go('/employees?q=NO-MATCH-LOCAL-QA'); await wait("document.body.innerText.includes('No employees on this page')")
  assert(!await evaluate("document.body.innerText.includes('Page 1 of 0')"), 'Zero results omit an invalid page fraction')
  const one = await get('/employees?q=ACME-00001')
  const response = await fetch(`${api}/api/v1/employees/export.csv?q=ACME-00001&sort=name&direction=desc`)
  const csv = await response.text()
  assert(response.ok && csv.includes('salary_effective_from') && csv.includes('ACME-00001') && csv.trim().split('\r\n').length === 2, 'Filtered CSV downloads one matching employee')
  await go(`/employees/${one.data[0].id}`); await wait("document.body.innerText.includes('Salary history') && document.body.innerText.includes('Current salary')")
  checks.push('Employee details, current compensation and history load')
  let longHistoryNavigationMs
  if (writes) {
    const started = performance.now()
    await go('/employees/10001')
    await wait("document.querySelectorAll('table tbody tr').length >= 1000")
    longHistoryNavigationMs = Math.round(performance.now() - started)
    assert(await evaluate("document.querySelectorAll('table tbody tr').length >= 1000"), 'All 1,000 history records render')
    await click("[...document.querySelectorAll('a')].find(e => e.textContent.includes('Revise salary'))")
    await wait("!!document.querySelector('textarea')")
    await click("document.querySelector('button[type=submit]')")
    await wait("document.body.innerText.includes('Enter a revision reason.') && document.body.innerText.includes('Enter the demo write key')")
    checks.push('Required revision validation prevents an empty submission')
    await input('input[inputmode=decimal]', '2100.00')
    await input('textarea', '😀'.repeat(255))
    await input('input[type=password]', 'intentionally-invalid-local-key')
    await click("document.querySelector('button[type=submit]')")
    await wait("document.body.innerText.includes('write key was not accepted') && document.querySelector('input[type=password]').value === ''")
    checks.push('255 supplementary code points reach Rails; real401 clears key')
    await input('input[type=password]', process.env.QA_WRITE_KEY)
    await click("document.querySelector('button[type=submit]')")
    await wait("document.body.innerText.includes('Salary revision saved.')")
    checks.push('Real revision succeeds and history is refreshed on disposable data')
    await click("[...document.querySelectorAll('a')].find(e => e.textContent.includes('Revise salary'))")
    await wait("!!document.querySelector('textarea')")
    assert(await evaluate('document.querySelector("input[type=password]").value.length > 0'), 'Key survives in-app navigation')
    assert(await evaluate('localStorage.length === 0 && sessionStorage.length === 0'), 'Key is absent from local/session storage')
    const current = (await get('/employees/10001')).data.current_salary
    const changed = await fetch(`${api}/api/v1/employees/10001/salary_revisions`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${process.env.QA_WRITE_KEY}` }, body: JSON.stringify({ salary_revision: { amount: '2200.00', currency: 'USD', pay_frequency: 'annual', reason: 'Independent disposable edit', expected_current_salary_record_id: current.id } }) })
    if (changed.status !== 201) throw new Error('Independent disposable edit failed')
    await input('input[inputmode=decimal]', '2300.00'); await input('textarea', 'Review stale salary')
    await click("document.querySelector('button[type=submit]')")
    await wait("document.body.innerText.includes('This salary changed while you were editing')")
    await wait("[...document.querySelectorAll('button')].some(e => e.textContent === 'Review latest salary and reset form' && !e.disabled)")
    await click("[...document.querySelectorAll('button')].find(e => e.textContent === 'Review latest salary and reset form')")
    await wait("document.querySelector('input[inputmode=decimal]').value === '2200.00'")
    checks.push('Real stale409 requires review and loads latest salary without overwrite')
  }
  await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true })
  assert(!await evaluate('document.documentElement.scrollWidth > innerWidth'), 'Mobile390 layout has no viewport overflow')
  await evaluate('document.activeElement.blur()')
  await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 })
  await call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 })
  assert(await evaluate("document.activeElement !== document.body && (getComputedStyle(document.activeElement).outlineStyle !== 'none' || getComputedStyle(document.activeElement).boxShadow !== 'none')"), 'Keyboard Tab moves focus with a visible focus style')
  if (errors.length) throw new Error(errors.join('; '))
  if (!writes && requests.some((request) => request.method !== 'GET')) throw new Error('Read-only smoke unexpectedly wrote data')
  console.log(JSON.stringify({ checks, longHistoryNavigationMs, runtimeErrors: errors.length, mode: writes ? 'attested disposable fixture' : 'read-only' }, null, 2))
} finally { socket.close() }
