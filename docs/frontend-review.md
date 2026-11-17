# Frontend MVP implementation and local integration review

Date: 17 November 2026. Branch: `main`. Baseline: `08ef57b`.

## A. Implementation inventory and requirement verification

The explicit frontend implementation request authorized this work. Historical gate restrictions and backend reports remain recorded as written; this report does not approve G1, close DR-20/DR-22, or establish owner phase acceptance. Requirements, API contracts and implementation-plan Phases 8–10 were checked against the actual controllers, serializers and queries before implementation and reread at completion. The pre-code inventory was recorded locally in `/tmp/acme-frontend-review/inventory.txt`.

All required frontend workflows supported by the approved contracts are implemented. “PASS” below means the named checks passed; it does not claim hosted, multi-browser or assistive-technology certification. Paths in this table are relative to `frontend/src/` unless stated otherwise.

| Requirement / plan acceptance | Implementation | Actual endpoint | Evidence and result | Remaining blocker |
|---|---|---|---|---|
| Phase 8 typed client, centralized origin, safe query construction and typed errors | `types/api.ts`, `lib/api.ts`, `features/reference-data/queries.ts` | All endpoints below | `lib/api.test.ts`; typecheck; actual browser reads/writes: PASS | Hosted origin deferred |
| Money remains decimal strings, display formatting only | `lib/format.ts`, all compensation views | Server salary/analytics fields | `lib/format.test.ts`, API and workflow tests; source review: PASS | None for local MVP |
| Reference-driven country, department, level, status, currency and frequency options | `features/reference-data/queries.ts`, `components/common/ReferenceFilters.tsx`, revision form | `GET /api/v1/reference_data` | Shared query, reference failure, usable-FX currency tests; actual controls: PASS | None |
| Responsive shell, working routes, active navigation, keyboard labels and feedback | `components/layout/AppLayout.tsx`, `app/router.tsx`, `components/common/Feedback.tsx`, `styles/index.css` | `/up` for retained status screen | Router/health/navigation tests; real desktop and 390px Chrome pass; focusable scrolling tables: PASS | Human screen-reader/multi-browser checks unperformed |
| Employee listing and name/ID search with debounce, no browser-wide download | `features/employees/DirectoryPage.tsx` | `GET /api/v1/employees` | Directory tests and real seeded search: PASS; 300ms debounce and server pagination | None |
| Country/department/status filters; supported sorting and direction; page/size/count | Directory page, reference filters | Same directory endpoint | Filter→URL→request, sort, pagination and reset tests: PASS | No directory level filter exists in contract |
| Preserve URL filters across pages and profile/revision/cancel navigation | Directory, employee and revision pages | Same reads | Dedicated round-trip navigation test: PASS | None |
| Loading, API/refdata errors, empty results, malformed query and 404 states | Shared feedback and feature pages | Actual read endpoints | Workflow tests and real employee 404: PASS | None |
| Profile identity, country/department/level/status, employment dates, current or last-held pay | `features/employees/EmployeePage.tsx` | `GET /api/v1/employees/:id` | Profile tests and actual seeded active/on-leave/terminated profiles: PASS | None |
| Complete, newest-first read-only history with amount, currency, frequency, effective/end timestamps, reason and FX snapshots | Employee page, formatter | Same detail response, `salary_history` | History tests; real revision preserves prior value and adjacent boundary; microseconds retained: PASS | Long-history performance not benchmarked |
| Active/on-leave/terminated eligibility and exclusions | Employee/revision pages, dashboard | `can_revise_salary`, status and analytics fields | On-leave allowed; terminated hidden and direct revision route blocked; RTL + real browser: PASS | None |
| Decimal-string amount, nonzero/max constraint, required trimmed 1–255 reason, available currency/frequency | `features/salary-revisions/SalaryRevisionPage.tsx` | `POST /api/v1/employees/:id/salary_revisions` | Required/invalid/max/input-string tests: PASS; server remains authoritative | None |
| No-change, missing FX and backend field validation errors | Revision page | Same POST | Per-code `no_change`, `missing_exchange_rate`, `validation_failed` tests: PASS | None |
| Exact concurrency token, stale refresh and explicit review; no silent overwrite | Revision page | Same POST + detail refetch | RTL token/reset test and real concurrent edit→409→review/reset: PASS | None |
| Single in-flight submission, no automatic POST retry, explicit save/cancel and confirmed success | Revision page, `lib/query-client.ts` | Same POST | Duplicate submit, denied-write count and success tests; real 201: PASS | None |
| Refresh confirmed compensation/history and invalidate employee/directory/dashboard queries | Revision page and shared query hooks | POST response + affected GETs | Cache invalidation and visible response tests; actual profile/history refresh: PASS | None |
| Memory-only write key above router; POST-only header; clear on 401/reload; fail closed on 403 | `app/WriteKeyProvider.tsx`, `app/write-key-context.ts`, layout, client | Revision POST only | Navigation/remount/storage/header/401/403 tests; actual 401 and keyless-server 403: PASS | Demo-only protection, as approved |
| Consistent 400/401/403/404/409/422/500/network feedback | Client, feedback, revision page | All contracted endpoints | API tests + per-code workflow tests; real 400/401/403/404/409: PASS | Not every error injected into real Rails |
| Filtered, sorted CSV excluding pagination; no key; reconciliation caveat | Directory page, `api.exportUrl` | `GET /api/v1/employees/export.csv` | Export URL test; real CSV header + one matched row: PASS | None |
| Dashboard active annual USD total, active headcount, average and exact median | `features/dashboard/DashboardPage.tsx` | `GET /api/v1/analytics/summary` | API-provided values asserted in RTL; actual seeded dashboard: PASS | None |
| Country and department distributions, group sizes, local-currency totals, group mean/median | Dashboard page | Same summary, `by_country`, `by_department` | Tables render actual response; workflow assertions and browser: PASS | None |
| Country/department/job-level dashboard filters in URL | Dashboard page, shared filters | Same endpoint | Filter→request tests; real level filter: PASS | None |
| Counts for all statuses, low-sample flags, null statistics/empty states and caveats | Dashboard page, status badge | Summary status counts and server flags | API-value, small-sample, empty/error/loading tests: PASS | None |
| Scale data, no client FX/annualization/mean/median/salary aggregation, illustrative rate labels | Dashboard/profile/formatter | Server-computed decimal fields | Source inspection + real 10,000-employee DB; PASS | Phase 10 performance measurements outstanding |
| Meaningful existing-stack tests, configured production build and local integration | Test files listed below; unchanged toolchain/manifests | Actual Rails/PostgreSQL + compiled React | 44 tests, typecheck, lint, build; 14 browser checks plus real 403/CORS/invariants: PASS | See I |
| Documentation, local run instructions and gate preservation | Root README, frontend README, this report | N/A | Reviewed: PASS | G1/hosted/owner acceptance deliberately open |

The backend supports job-level **analytics filtering**, not directory level filtering or a by-level aggregate. It supplies country/department compensation distributions, not histogram buckets or monthly organization totals. The original requirements and Phase 9 acceptance require those supported group tables and annual USD reporting; no unsupported endpoint, invented statistic or optional product page was added. Headcount meters are lightweight accessible count displays, not calculated salary charts. Individual monthly/annual frequency is retained and labeled.

## B. Files created and modified

No files deleted. No dependency manifests, lockfiles, backend files, Makefile, environment examples or approved decision documents changed.

### Modified (11)

- `README.md`
- `frontend/README.md`
- `frontend/src/app/App.tsx`
- `frontend/src/app/router.test.tsx`
- `frontend/src/app/router.tsx`
- `frontend/src/components/layout/AppLayout.tsx`
- `frontend/src/features/health/StatusPage.test.tsx`
- `frontend/src/lib/api.ts`
- `frontend/src/lib/query-client.ts`
- `frontend/src/styles/index.css`
- `frontend/src/test/renderRoute.tsx`

### Added (17)

- `frontend/src/app/WriteKeyProvider.tsx`
- `frontend/src/app/write-key-context.ts`
- `frontend/src/components/common/Feedback.tsx`
- `frontend/src/components/common/ReferenceFilters.tsx`
- `frontend/src/components/common/StatusBadge.tsx`
- `frontend/src/features/dashboard/DashboardPage.tsx`
- `frontend/src/features/employees/DirectoryPage.tsx`
- `frontend/src/features/employees/EmployeePage.tsx`
- `frontend/src/features/reference-data/queries.ts`
- `frontend/src/features/salary-revisions/SalaryRevisionPage.tsx`
- `frontend/src/lib/api.test.ts`
- `frontend/src/lib/format.test.ts`
- `frontend/src/lib/format.ts`
- `frontend/src/test/fixtures.ts`
- `frontend/src/test/workflows.test.tsx`
- `frontend/src/types/api.ts`
- `docs/frontend-review.md`

## C. Screens implemented

- `/`: compensation overview, supported filters, actual counts/statistics, country/department tables, local-currency totals, headcount meters and interpretation notes.
- `/employees`: debounced search, reference-driven filters, documented sorts/direction, server page/size controls, total count, employee links and matching CSV export.
- `/employees/:id`: identity, employment details, current or last-held salary, eligibility and complete read-only newest-first salary history.
- `/employees/:id/revise`: current compensation, immediate revision form, validation, save/cancel, write-key entry, confirmed success and safe error/conflict recovery.
- `/status`: existing real API health check. Unknown routes show the not-found page.

Desktop and mobile screenshots were inspected locally. Horizontal data tables remain contained and keyboard focusable. No placeholder navigation or production mock layer was introduced.

## D. Backend integration

Connected `GET /up`, `GET /api/v1/reference_data`, `GET /api/v1/employees`, `GET /api/v1/employees/:id`, `GET /api/v1/employees/export.csv`, `GET /api/v1/analytics/summary` and `POST /api/v1/employees/:id/salary_revisions`.

Actual verification used Ruby 4.0.9, Rails from the existing lockfile, Node 26.13.1/npm 12.2.2, PostgreSQL 14.25 and the already installed Chrome. The compiled Vite build ran on `127.0.0.1:5173`, Rails on `127.0.0.1:3100`. PostgreSQL was an isolated Unix-socket cluster under `/tmp/acme-backend-review`, port 55441 with TCP disabled. A new separate database `acme_frontend_integration_development` was prepared and deterministically seeded: 10,000 employees, 16,055 initial salary records, 9,200 active/300 on leave/500 terminated. Only this disposable database received test revisions.

Fourteen actual browser checks passed: seeded dashboard; level filter; directory search/count; filtered CSV; profile/history; invalid-key 401; successful revision and exact prior-history boundary; independent concurrent edit and stale 409 with explicit reset; memory-only key/no GET authorization; terminated behavior; on-leave eligibility; employee 404; 390px responsive navigation/no viewport overflow; no uncaught frontend runtime exceptions. They passed again against the final compiled assets. A separate keyless Rails run confirmed real 403 hides the form, clears the key, permits reads and sends only one POST.

Additional real HTTP checks: health 200; allowed Vite-origin preflight with Authorization; unlisted origin denied; unsupported sort 400 `invalid_parameter`. Final SQL integrity counts were `10000|0|0|0`: employees, employees without exactly one open salary record, overlapping periods, gaps between adjacent periods. No production database was accessed. These four queries are targeted regression evidence, not a claim that every domain invariant/performance case was re-audited.

No backend correction or CORS configuration change was necessary. Temporary servers are stopped after verification. Disposable artifacts remain outside Git under `/tmp/acme-frontend-review` (check logs, browser scripts/results and screenshots).

## E. Salary revision workflow

Amount remains a string through input, validation and POST. Syntax checks reject exponent notation, extra precision, nonpositive values and values beyond the documented maximum without converting or comparing money numerically. The backend decides whether compensation is unchanged and whether FX/eligibility/history constraints pass. Only reference currencies with usable rates are offered. The current salary ID is submitted verbatim as the concurrency token.

A synchronous in-flight guard and disabled controls prevent duplicate submits; mutations never retry automatically. Stale 409 refreshes current data and requires an explicit review/reset before another write. Confirmed POST records update the detail cache and relevant reads are invalidated. Historical records have no edit/delete controls.

The write key exists only in React state above the router. It is entered through a password input, never sourced from a public Vite variable, never stored in browser storage/cookies/URLs, and sent only as the documented revision Authorization header. 401 discards it; 403 clears it and hides the form. Reload/remount loses it. A visible forget action clears it. Synthetic local verification keys were not placed in repository files or the built bundle.

## F. Dashboard

All monetary totals, normalization, averages, medians and group flags are returned by Rails/PostgreSQL. React formats decimal strings without financial arithmetic. Headcount totals/meters operate only on integer employee counts. Tables show annual USD base pay with country/department group sizes, local-currency totals and low-sample indicators; no chart dependency was installed. Active-only totals, illustrative FX, fewer-than-ten sample warning and comparison limitations are stated visibly. Empty groups show zero total and unavailable mean/median rather than invented values.

## G. Tests and verification commands

Final command from the repository root:

```sh
export PATH=/Users/vijaypatidar/.nvm/versions/node/v26.13.1/bin:$PATH
VITE_API_BASE_URL=http://127.0.0.1:3100 make frontend-check
```

This ran the existing `npm run typecheck`, `npm run lint`, `npm test` and `npm run build`. Results: TypeScript PASS; ESLint PASS; Vitest **44 tests in 5 files PASS**, 3.82 seconds; configured Vite production build PASS, 87 modules. Output: CSS 21.36 kB (gzip 5.90), JS 385.02 kB (gzip 117.79). Build sizes are observations, not performance guarantees.

Tests: `src/lib/api.test.ts`, `src/lib/format.test.ts`, `src/test/workflows.test.tsx`, existing `src/app/router.test.tsx`, existing `src/features/health/StatusPage.test.tsx`. Test mocks remain confined to test code. Covered paths include directory/search/filters/paging/sort/export/round-trip navigation; profile/history/status/404; dashboard values/filters/loading/empty/errors/small samples; required/invalid/max revision input; response refresh; per-code errors; stale reset; duplicate writes; memory-only key/navigation/remount/forget; reference errors and missing usable currency.

Actual browser automation used native Chrome DevTools Protocol with Node, without adding a package or downloading a browser:

```sh
/Users/vijaypatidar/.nvm/versions/node/v26.13.1/bin/node /tmp/acme-frontend-review/browser.mjs
/Users/vijaypatidar/.nvm/versions/node/v26.13.1/bin/node /tmp/acme-frontend-review/browser-disabled.mjs
```

Both passed; the second requires the temporary server to run without its write key. These are local review artifacts, not portable project test commands. Results/logs are in the same temporary directory. Screenshots: `dashboard.png`, `employee.png`, `mobile.png`.

Final `git diff --check` and `git diff --cached --check`: PASS. Backend source and lockfiles remained byte-identical to task entry; the previous 344-example backend report remains historical and was not unnecessarily rerun.

Intermediate failures were resolved: an initial command ran npm from the wrong directory; the shell selected an older Node until PATH was explicit; ESLint caught two expression statements which were corrected; one test cache assertion needed retained inactive-query cache because the test harness uses `gcTime: 0`. Final checks ran after all source corrections and passed. No final frontend check is blocked.

## H. Local setup

Use the existing installed Ruby/Node toolchains and locked dependencies. Exact normal development instructions are maintained in [`frontend/README.md`](../frontend/README.md), including new-database-only preparation/seed guidance. In separate terminals:

```sh
# Start the existing local service; this machine uses Homebrew PostgreSQL 14.
brew services start postgresql@14

# First-time dependency/database setup from root, with DATABASE_URL reviewed:
make setup

# Backend terminal, Ruby 4.0.9:
cd backend
# On a NEW disposable local database, seed if not already seeded:
bin/rails db:seed
read -r -s DEMO_WRITE_KEY
export DEMO_WRITE_KEY
bin/rails server

# Frontend terminal:
cd frontend
npm run dev
```

Open `http://localhost:5173`; development API defaults to `http://localhost:3000`. Only public `VITE_API_BASE_URL` belongs in frontend configuration. Rails requires the privately entered `DEMO_WRITE_KEY` for writes; enter the same value in the UI. Existing example files remain unchanged. A runnable production build requires `VITE_API_BASE_URL=http://localhost:3000 npm run build`; local preview must use `npm run preview -- --port 5173` to match existing development CORS. This is local build verification, not a production deployment configuration.

For reproducibility, the review used the isolated socket/port/database described in D, `RAILS_ENV=development`, a locally supplied server key, `bin/rails db:prepare`, Rails `-b 127.0.0.1 -p 3100`, and the public frontend origin variable pointing to that port. No shared service needed reconfiguration.

## I. Remaining requirements, limitations and decisions

- No supported frontend MVP feature is known missing. Phases 8–9 implementation and their local workflow checks are complete; owner acceptance remains separate.
- Phase 10 is partially verified: real seeded workflows and targeted history invariants passed. EXPLAIN ANALYZE/timing benchmarks for list/filter/search/analytics/export and a long-history fixture were not performed in this frontend task. No performance target or index change is claimed.
- Human screen-reader testing and browsers other than installed Chrome remain unverified. Responsive viewport behavior was checked at 390px and desktop, not every device.
- Hosted PostgreSQL 17/18/Neon `btree_gist`/exclusion-constraint/full setup verification and owner sign-off remain pending. G1 remains OPEN. DR-20 provider selection and pending hosted verification are unchanged. DR-22 hosting/topology/production CORS remains OPEN.
- Deployment, production demo verification, hosted CI, fresh-clone reinstall, video demonstration, and incremental owner commits remain outside this local implementation task. No production URLs or resources were added.
- No optional histogram, by-level aggregate, monthly organization total, full authentication or unsupported directory filter was invented.

## J. Git status and change scope

Branch `main`; HEAD remains `08ef57b`. Task entry had a clean working tree and empty index. Final changes: **11 modified tracked files and 17 new files (28 total), no deletions, no staged changes**. The new report is included in that count. The tracked diff stat excludes the new files until staged; use the full lists in B to review all work.

Backend files, dependency manifests/lockfiles, original environment files, Makefile and decision/gate documents were preserved. Build output and local credentials remain ignored/outside the repository. No `git add`, commit, push, reset or clean was performed. Final review compared tracked hashes to task-entry hashes and inspected changed/new file content.

## K. Conclusion

The supported frontend MVP is implemented and has been verified end to end locally against actual Rails/PostgreSQL, including successful and stale revisions, read-only history, export and fail-closed write protection. This establishes local integration evidence, not production readiness or completion of unmeasured Phase 10/hosted work.

No production deployment work. No cloud resources created. No production database touched. No secrets committed. No dependency or backend business-rule changes. G1 remains OPEN; DR-20 and DR-22 retain their documented states. Nothing staged, committed or pushed.

## Frontend staging review — 17 November 2026

This follow-up review leaves the implementation record above as historical evidence. At staging-review entry the index was empty, with 12 modified tracked files and 17 new files. The extra tracked change was `backend/db/schema.rb`: two existing CHECK expressions have different cast placement. That change predates this staging task; it is preserved byte-for-byte and excluded from the frontend index. The root README changes concern frontend completion, the review link and the configured frontend check command, so they belong with this frontend work.

A fresh `VITE_API_BASE_URL=http://localhost:3000 make frontend-check` using Node 26.13.1 initially passed typecheck/lint but failed one debounce assertion (43 passed, 1 failed). URL navigation had completed before the asynchronous query request was observed. The sole code correction in this staging task makes that existing test assertion await the request count with `waitFor`; application behavior is unchanged. The complete command then passed typecheck, ESLint, all 44 tests in 5 files (3.60 seconds), and the production build (87 modules; CSS 21.38 kB, JS 385.02 kB). Browser integration was not repeated: production source matches the previous verified snapshot; only this test and this report changed during staging review.

The reviewed frontend commit scope is 28 files: 10 tracked frontend modifications, 16 new frontend files, the related root README and this report. No deletions, dependency edits, backend files, real environment files, build output, browser artifacts or logs belong in that scope. Ignore rules exclude local environment files, node_modules, dist and logs; the unchanged frontend environment example contains only a public localhost API origin. Test-only key literals are clearly synthetic fixtures. Staged content is reviewed against working-file hashes and whitespace checks before the final response. G1, DR-20 and DR-22 remain unchanged. No features, dependencies, cloud resources, commits or pushes are added by this staging review.
