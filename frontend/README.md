# ACME Salary Management — frontend

React 19, TypeScript strict, Vite, React Router, TanStack Query, Tailwind CSS 4, Vitest and React Testing Library. No additional dependency was needed for the completed frontend MVP.

## Run locally

Use the repository's installed Node 26.13.1/npm 12.2.2 toolchain. From the repository root:

```sh
make setup
```

This installs the existing locked dependencies and prepares the configured local databases. Review `DATABASE_URL` before preparing any database; never seed an existing database containing user data.

Start PostgreSQL using your existing local service (the reviewed machine uses Homebrew):

```sh
brew services start postgresql@14
```

In the backend terminal, use Ruby 4.0.9 (`backend/.ruby-version`), then:

```sh
cd backend
# On a new, disposable local database only:
bin/rails db:prepare
bin/rails db:seed
# Enter a locally chosen key without placing it in command history:
read -r -s DEMO_WRITE_KEY
export DEMO_WRITE_KEY
bin/rails server
```

In another terminal:

```sh
cd frontend
npm run dev
```

Open `http://localhost:5173`. The default API origin is `http://localhost:3000`. `http://localhost:5173` and `http://127.0.0.1:5173` are already allowed by the backend's development CORS configuration, including revision preflight headers.

Local PostgreSQL 14.25 was used for these checks. Verification on the eventual supported hosted PostgreSQL major 17/18 remains outstanding; do not treat the local Homebrew command as the production database decision.

## Configuration

`VITE_API_BASE_URL` is the public API origin, without a trailing slash. It is optional in development and required when building a runnable production bundle. Example:

```sh
VITE_API_BASE_URL=http://localhost:3000 npm run build
npm run preview -- --port 5173
```

Use port 5173 for local preview to match existing development CORS. For another port, explicitly configure the backend's `CORS_ALLOWED_ORIGINS`. Production topology/CORS and hosting remain DR-22; no deployment configuration is included.

The frontend never reads `DEMO_WRITE_KEY`. Enter the server-configured key in the password field on the revision form. It is held only in React memory above the router, survives in-app navigation, is cleared on 401/reload/tab close, and can be forgotten explicitly. It is never stored in browser storage, cookies, URLs or a `VITE_*` variable. Reads and CSV export send no write key. An unconfigured server refuses writes with 403; the form then stays hidden until the app is reloaded.

## Screens

| Route | Working behavior |
|-------|------------------|
| `/` | Active base-pay totals, average/median, status counts, country/department tables, local-currency totals, headcount meters, small-sample warnings; URL country/department/level filters |
| `/employees` | Debounced name/ID search, country/department/status filters, all documented sorts, direction, server pagination/page size, profile links and filtered CSV export |
| `/employees/:id` | Employee details, eligibility and current/last-held salary; complete newest-first read-only history, UTC microseconds and FX snapshots |
| `/employees/:id/revise` | Decimal-string input, reason, usable-currency/frequency controls, memory-only write key, concurrency token, safe error handling and cache refresh |
| `/status` | Live framework health check |
| Unknown route | Not-found page |

Directory query state survives paging and profile/revision/cancel navigation. Dashboard level filtering is supported; the backend has no directory level filter, by-level aggregate, salary histogram or monthly organization total. Those features were not fabricated. Compensation distributions use the approved country/department tables; headcount meters represent employee counts, not money.

## Checks

From the root:

```sh
VITE_API_BASE_URL=http://localhost:3000 make frontend-check
```

This runs `npm run typecheck`, `npm run lint`, `npm test` and `npm run build`. `npm run test:watch` is available for development. The final review passed 55 tests in 5 files, typecheck, lint and a configured production build. Browser integration also passed against the actual Rails/PostgreSQL service and its compiled frontend; see [`docs/frontend-review.md`](../docs/frontend-review.md).

## Current local corrections and reproducible browser checks

Search retains its input instance, keyboard focus and unfinished draft while filters/pages change;
actual query/back/forward/clear changes synchronize deliberately. Empty results omit a zero-page
fraction. Revision reasons use Ruby-compatible outer ASCII-whitespace trimming and Unicode
codepoint counting (not grapheme clusters), with the backend still authoritative.

See [`docs/local-browser-smoke.md`](../docs/local-browser-smoke.md) for the dependency-free native
Chrome procedure, including disposable-only revisions/stale conflicts and 1,000-record history.
`node script/local-smoke.mjs` defaults to GET-only mode against localhost; it never writes unless
explicit disposable opt-in, a server key and the named QA fixture are all present. The actual QA
results, accessible keyboard checks and limits are in
[`docs/final-local-qa.md`](../docs/final-local-qa.md). No screen-reader certification is claimed.

## Implementation notes and limits

- API contracts and types live in `src/types/api.ts`; `src/lib/api.ts` owns URL construction and error codes. Queries use TanStack Query and write requests never retry automatically.
- `src/lib/format.ts` formats decimal strings without numeric conversion, rounding, comparison or financial arithmetic. All annualization, FX, sums, means and medians come from Rails/PostgreSQL.
- Salary forms carry the current record ID. A stale 409 refetches the employee and requires an explicit review/reset before another submission. A successful POST uses the confirmed response and invalidates employee, directory and dashboard queries.
- CSV follows directory filters/sort and excludes paging. Its sum matches dashboard totals only for active-only export with matching country/department scope, no search and no dashboard level filter.
- All data is synthetic. Rates are fixed illustrations. Peer comparisons are not compa-ratios or evidence of inequity/attrition.
- No application mock layer ships in production. Test fixtures and fetch mocks are confined to tests.
- Mobile layout, keyboard-focusable horizontal tables, labeled inputs, skip link, active navigation, loading/empty/error feedback and exact UTC timestamps are included.
- The earlier reports remain historical. G1 remains OPEN; hosted DR-20 verification, DR-22, owner phase acceptance, cross-browser/screen-reader testing and performance benchmarks remain separate. No cloud resources or deployment were created.
