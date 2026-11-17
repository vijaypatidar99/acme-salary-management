# Final local MVP corrections and quality verification

Date: 17 November 2026. Branch: `main`, baseline HEAD: `bd4e207`. This task corrects the authorized local defects; it does not deploy, rebuild the MVP or approve architectural gates. The earlier assessment audit and backend/frontend reports remain historical evidence.

## A. Confirmed defects corrected

| Finding | Cause and correction | Files / regression evidence |
|---|---|---|
| P0 test-target safety | Inherited development mode and DATABASE_URL could select data used by destructive specs. Environment is now validated before Rails boot; every new PostgreSQL adapter client is checked read-only against explicit target identity and a random disposable marker before writes are enabled. | `backend/spec/rails_helper.rb`, `spec/test_database_safety.rb`, `spec/safety/test_database_safety_spec.rb`; 6 database-free subprocess cases, real safe/unsafe connection probes, full suite |
| P1 search focus/draft | Query-string key remounted the input after debounce. Input instance now persists; actual q/back/forward/clear changes synchronize state, filters/pages preserve the pending draft, and the delayed callback uses current URL state. | `frontend/src/features/employees/DirectoryPage.tsx`, `src/test/workflows.test.tsx`; keyboard pause/continue, Back/Forward, clear, pending draft/filter/page tests; actual Chrome |
| P1 Unicode reason length | JS counted UTF-16 units and used different whitespace semantics. Reasons now use Ruby-compatible outer ASCII whitespace stripping and codepoint length; Rails remains authoritative. | `SalaryRevisionPage.tsx`, workflow tests and backend service reason-boundary specs;255 supplementary codepoints accepted in real POST |
| P2 zero-page presentation | Literal page/total rendering produced “Page 1 of 0”. Empty results now show count without a page fraction; normal/beyond-last paging behavior remains intact. | Directory page; no matches, beyond-last recovery, filter transitions and normal page regressions |
| P2 CSV timestamp precision | CSV used default iso8601 precision. It now uses the existing `Timestamp.call` formatter with six fractional digits. | CSV service, unit exact-value/fractional timestamp regression and request expectations; full suite |

No salary calculation, status eligibility, FX selection, concurrency rule, database schema or API endpoint was redesigned. No history facts were rewritten on development.

## B. Test database safety

### Guard and isolation mechanism

`TestDatabaseSafety.configure!` runs before Rails/environment/schema code. Explicit non-test RAILS_ENV or RACK_ENV is rejected. Tests require an explicit ACME_TEST_DATABASE and a 64-hex-character ACME_TEST_DATABASE_TOKEN, plus compatible PostgreSQL DATABASE_URL if provided. Protected development/production/maintenance names, mismatched URL targets, remote hosts and service/address overrides fail closed; a database-name substring is never sufficient.

The PostgreSQL adapter factory is guarded before Rails boot and the first pooled connection is forced through validation before `maintain_test_schema!`. Each later pool connection/reconnect uses the same factory. Before connecting, the resolved database must match the declared target and local socket/loopback restrictions. The new session starts with PostgreSQL default_transaction_read_only=on. Read-only metadata verifies actual database name, server address, owner role, non-replica state and a matching `acme-rspec-disposable:` comment. Only then is the session enabled for test fixture writes. Invalid identity/attestation closes the connection. All current suite connections use this adapter; introducing raw driver/alternate adapter access must preserve the guard rather than bypass it.

`backend/script/prepare_test_database.rb` creates a NEW local randomly named DB only, refuses existing/protected targets, adds the disposable attestation, loads schema and prints a mode 0600 temporary environment-file path. It never adopts/cleans/resets/drops an existing DB. The mode 0600 file is outside Git. Existing deliberate local disposable targets can use exact declarations and an explicitly established matching marker/owner; unknown/shared databases must not be marked automatically. This protects accidental configuration, not a malicious operator deliberately falsifying disposability metadata.

### Evidence before mutating tests

1. Database-free subprocess cases ran first: unsafe development/production modes, missing/malformed or incompatible declarations, remote/overridden targets, the real rails_helper entry point, pre-connect rejection of later unsafe factories, and actual-identity validation/closing behavior. Final standalone result: 6 examples, 0 failures, 2.41s.
2. Real connection probe then accepted an empty attested target in Rails test mode and rejected a later attempt to establish backend_development before connecting. No fixture examples or writes ran during that probe.
3. Only afterward did the mutating suite run, exclusively against new local `acme_qa_60873_2e35a57d`, never backend_development. The full suite includes destructive/reset/rollback cases and is intentionally confined there.

The first positive socket URL probe exposed Ruby URI's empty host representation; the guard was corrected to accept an empty URL host only when the resolved local socket parameters and server attestation pass. Positive socket/loopback subprocess cases were added before the real probe/full suite. No unsafe configuration was relaxed to make a test pass.

The QA fixture/server was started only after the suite finished, so cleanup and browser checks did not share a concurrently mutating test dataset. Future runs must follow that ordering. Sourcing the generated test environment into the development server terminal is explicitly discouraged; use separate terminals.

## C. Frontend corrections and tests

Search remains debounced 300ms and server-paginated; it does not fetch 10,000 records into React. It preserves country/department/status/sort/direction when a pending draft commits, resets page on actual search/filter changes, retains focus after a pause and synchronizes browser Back/Forward. Clearing cancels the pending timer and clears the field. Zero-total results omit the fraction; a beyond-last page still offers recovery.

Reason coverage on both frontend and backend includes empty, ASCII-whitespace-only, one character, 255/256 ASCII and 255/256 supplementary Unicode codepoints. Surrounding ASCII whitespace is stripped consistently. Codepoint counting is not grapheme counting and no new rule was introduced. A real 255-emoji revision was confirmed on disposable data, with the resulting server history refreshed. Input money still remains a decimal string; the frontend does no financial arithmetic.

New Vitest cases additionally verify paused keyboard focus, continued typing, current-filter retention while a draft is pending, paging transitions, Back/Forward, clear and empty/beyond-last results. New tests await reference/query rendering instead of assuming the URL update alone completes the asynchronous request. All 55 tests pass.

## D. Backend correction: CSV precision

The authoritative API conventions specify UTC timestamps with microseconds. The CSV column example uses whole seconds, but there is no explicit CSV-specific precision exception; an example lacking fractional digits does not override the general convention. CSV therefore reuses `Timestamp.call`, just like JSON.

Regression output now preserves `2025-04-01T00:00:00.123456Z`; timestamps with no fraction emit `.000000Z`. Only exported formatting changed. Stored effectivity, CSV headers, row selection/order, quoting/sanitization, money/rates and date-only fields are unchanged. Both CSV unit and request expectations pass. No approved domain/API document was rewritten.

## E. Local full-stack verification

### Original development data — read-only

The existing local Rails server on 3000 and Homebrew PostgreSQL 14.25 `backend_development` were used through GET-only API/Chrome checks. All direct verification connections force database writes off. Final fingerprint/counts/distributions match the previously verified dataset, including the earlier audit snapshot:

- 10,000 employees; 16,055 salary records; 6,055 closed historical records; 10,000 open current/last-held records.
- 6 countries, 9 departments, 4 currencies, 4 exchange rates.
- 9,200 active, 300 on leave, 500 terminated; 5,545 monthly and 4,455 annual current salaries.
- Fingerprint: `040a37bf54ff252c0fd5cae2dfe83d35c975099c817f40cb820e95c2b08b882a`.
- All 21 integrity checks pass: no overlaps/gaps, missing open record, invalid amount/rate/reason/status/interval, FX mismatch, orphan references or identifiers outside the documented dataset.

The GET integration procedure verifies directory count and distinct pages, unique employee-number search, employee/current/history responses, country/status/department filters, reference data, analytics totals/groups/filters and a representative filtered CSV. Actual organization total remains USD 586,288,203.19 annually over 9,200 active employees; mean 63,726.98 and median 54,600.00 come from Rails/PostgreSQL.

The new repository-owned smoke script passed 9 read-only browser checks on the same data: dashboard/distributions, focus/continued search, clear/filter/paging, empty presentation, CSV, profile/history, mobile 390 and keyboard focus. It observed no POST or uncaught runtime exception. Normal local development works without Neon or production infrastructure. Temporary Vite was pointed to 3000 for this pass; the existing Rails/PostgreSQL services were not reconfigured or stopped.

### Disposable writes and concurrency recovery

`script/local_qa_fixture.rb` checks the same guard and requires an empty attested target, then creates 300 deterministic small-seed employees and one named QA-only employee 10001 with 1,000 contiguous salary records. This intentionally differs from the production-style 10,000 dataset and must never be confused with development seed counts. The guard/name/marker checks happen before fixture creation.

A separate Rails test server on 3102 and React on 5173 were used. The native Chrome script requires explicit disposable write opt-in, target declaration, a privately supplied QA key and the QA fixture's identity before writing. Its 16 checks passed: dashboard, focus pause/continue, clear/filter/page reset, zero-page presentation, CSV, profile/history, all 1,000 rows rendered, required validation, invalid-key 401 clearing,255-codepoint valid revision, cache/history refresh, memory-only key across navigation, independent edit followed by stale 409 with explicit review/reset, mobile containment and visible keyboard focus. It records no request bodies/keys/headers in its output.

Two valid revisions were made only to QA-LOCAL-10001: one via the UI and one independent API edit to create the stale condition. The attempted stale POST did not overwrite the independent value; explicit reset displayed the newer server salary. Afterward the disposable dataset has 301 employees, 1,463 salaries and 1,162 closed records; seed history/open-record/FX verification passes for that fixture population. Development salaries were never revised.

## F. Long-history and accessibility verification

Long-history fixture: 1,000 original records (999 closed, one open) on QA employee 10001. Chrome rendered all original rows with the current complete-history API; navigation-to-detected-render observation was 397ms. This includes local Vite/CDP/polling overhead, not an isolated React rendering benchmark.

After the two QA revisions, measured detail history contained 1,002 records:

| Measurement | Actual observation |
|---|---|
| Method | Five uncached warm in-process Rails GETs, read-only connection; includes serializer/response construction, excludes external network |
| Times (ms) | 155.024,49.577,45.267,44.777,55.115 |
| Median / range | 49.577ms /44.777–155.024ms |
| SELECT statements | 4 on every run |
| JSON response | 318,644 bytes on every run |
| Browser original-table render | All 1,000 rows observed, 397ms navigation-to-detection |
| Environment |Apple M1; Ruby 4.0.9/Rails 8.1.4.1, PostgreSQL 14.25 local socket, installed Chrome, Node 26.13.1 |

There was no N+1 growth in the detail read; query count stays 4. This fixture does not prove unlimited history capacity, mobile performance on weak hardware, hosted bandwidth, cold-start/load behavior or a universal latency threshold. The approved complete, unpaginated history contract is retained. No index, cache or pagination redesign was justified or added.

Native browser input events confirmed keyboard Tab moves focus and computed focus styling is visible. Search pause/continue was tested with actual browser input; revision validation and stale review controls were exercised. Both read-only and disposable passes at 390px had no viewport overflow. Shared labeled controls, skip link and contained tables remain present. The committed smoke document includes a human keyboard/table/validation checklist.

**Not performed:** real screen-reader/assistive-technology review, multiple browser engines, exhaustive zoom/device/maximum-content layouts. No screen-reader certification or full accessibility conformance is claimed.

## G. Automated checks: exact commands and results

Use the installed Ruby 4.0.9 and Node 26.13.1 toolchain paths in PATH. No package/gem/browser framework was installed or upgraded.

| Command / context | Result |
|---|---|
| From backend: `bundle exec rspec spec/safety/test_database_safety_spec.rb`, no Rails helper/DB loaded | 6 examples, 0 failures; verified independently before mutating specs |
| `ruby script/prepare_test_database.rb`, then source its printed environment file in the test terminal |New local attested target/schema prepared; no existing DB adopted/reset/dropped |
| `FULL_SEED=1 bundle exec rspec --seed 47214`, with that attested test environment |**358 examples,0 failures**, 28.89s; includes full deterministic seed/reset/rollback and concurrency coverage |
| `bin/rubocop --cache false` | 86 files, 0 offenses |
| `bin/rubocop --cache false script/prepare_test_database.rb script/local_qa_fixture.rb` | 2 files, 0 offenses |
| `RAILS_ENV=development bin/rails zeitwerk:check` |PASS |
| `bundle exec brakeman --no-threads --quiet --no-pager --exit-on-warn --exit-on-error` | 0 report errors/0 security warnings; existing nonfatal Bundler/fileutils diagnostic noted |
| `bundle exec bundler-audit check --no-update` |No vulnerabilities in cached advisory DB; freshness not checked |
| Root: `VITE_API_BASE_URL=http://localhost:3000 make frontend-check` | TypeScript, ESLint, **55 tests/5 files**,configured production build PASS; final Vitest 6.33s |
| `node --check frontend/script/local-smoke.mjs` |PASS syntax |
| `bin/rails runner script/local_qa_fixture.rb`, attested isolated test environment |Prepared 300+1 fixture and 1,000 salary rows; refuses nonempty target |
| Frontend: `QA_API_ORIGIN=http://127.0.0.1:3102 QA_DISPOSABLE_WRITES=1 node script/local-smoke.mjs`, with target file and private QA_WRITE_KEY loaded | 16 actual disposable Chrome checks PASS; no runtime errors |
| Frontend: `node script/local-smoke.mjs`, Vite pointing to existing API 3000, no write opt-in | 9 read-only Chrome checks PASS; no runtime errors or writes |
| GET-only API procedure; read-only development integrity/fingerprint runner |PASS; all 21 checks and original data preserved |
| Read-only long-history GET measurement |Five responses, 1,002 records each, 4 queries each; measurements in F |
| `git diff --check`; `git diff --cached --check` |PASS; index unchanged |

Final build: 87 modules; JS 385.39kB (gzip 117.94),CSS 21.41kB (gzip 5.91). Sizes are measured artifacts, not performance targets. The tiny CSS difference reflects the current build's content scan; stylesheet source and dependencies were not edited.

Intermediate failures were investigated and corrected: a positive socket URL was initially rejected due to URI empty-host handling (fixed before mutating tests); ESLint rejected control-code regex notation, replaced by explicit Ruby whitespace-character checks; new async UI tests initially assumed reference options/page buttons were already rendered and now await them; RuboCop corrected bracket spacing in new tests. Audit-harness commands also initially used the wrong working directory, an invalid `--parallel false` argument and a Rails inline `require_relative` base; these were corrected without application changes. The final full checks listed above pass. Existing Rack 422-symbol/Bundler diagnostic warnings were not broadly refactored.

Reusable scripts/procedure are committed-source candidates; temporary logs and measurement harness output are under `/tmp/acme-local-qa`. Current test database retains the QA fixture for review. Its environment/marker declaration remains local and must not be staged. Provision another fresh target before rerunning full cleanup-oriented specs alongside fixtures.

## H. Documentation changes

- Root README: separate local terminals; safe development seed/key instructions; test target preparation; latest evidence/report links; concise factual AI-assisted development summary.
- Backend README: preserved prior seed evidence and added guarded-test provisioning, attestation, connection behavior, exact commands and current 358-example status.
- Frontend README: current 55-test result, focus/Unicode/pagination corrections, browser procedure and accessibility limits.
- New `docs/local-browser-smoke.md`: repeatable read-only and disposable-only procedures using the installed browser/native CDP; manual keyboard/accessibility checklist and limits.
- New this report: current A–K corrections/evidence/remaining requirements.

`docs/final-assessment-audit.md`, approved requirements/domain/architecture/API/plan/decision documents and earlier backend/frontend review reports remain byte-identical to task entry. Their historical defect descriptions are not silently rewritten; this report records resolution. The original assessment PDF remains unavailable; the existing assessment summary and requirements define the local inventory below.

## I. Remaining work and requirement verification

| Category | Current conclusion |
|---|---|
| Implemented and tested local MVP |HR persona/web UI; directory/search/filters/sort/server paging; details/status/current-or-last salary; complete read-only history; immediate atomic revisions with eligibility/token/stale/error/key handling; exact USD analytics/group distributions/means/medians; filtered safe CSV; deterministic 10k seed; reference controls; local Rails/PostgreSQL/React run path |
| Confirmed local corrections requested here |P0 guard, focus/draft/URL regression, Unicode length, empty pagination and CSV precision corrected with regressions and live evidence |
| Implemented but broader verification outstanding |Other browsers/assistive technology, very large history beyond the measured fixture, concurrent production load, fresh dependency reinstall/clean-clone run; no such claims made |
| Optional enhancements not required for local completion |Build-time missing-public-origin validation, cosmetic wrapping/layout polish; documented configured build works |
| Blocked by deployment/owner decisions |G1 hosted database evidence/sign-off; DR-20 hosted PG17/18 role/TLS/extension/exclusion/migration/seed verification; DR-22 host/topology/production CORS and release configuration |
| Incomplete submission requirements |Working deployed application/link, deployed video, original-PDF cross-check and final owner-reviewed repository/email handoff; broader Git history cannot be fabricated retroactively |
| Unsupported/excluded features |No payroll, employee CRUD, live FX, full auth/RBAC, histogram/by-level/monthly organization endpoints or unapproved infrastructure added |

No remaining confirmed P0/P1 local application defect from the authorized correction list is known uncorrected. This statement is scoped to reviewed/exercised behavior, not a guarantee that arbitrary undiscovered defects do not exist. Locally runnable does not mean production-ready; G1/DR-20/DR-22 remain open as documented.

## J. Git status and file inventory

Branch main; HEAD remains bd4e207. Entry had modified backend README/schema and the untracked assessment audit. The schema and assessment audit retain their exact entry bytes; prior README content/evidence is retained with authorized current instructions added. Staged content is unchanged. No dependency manifest/lockfile changes.

Task-modified tracked files (11):

- `README.md`
- `backend/README.md`
- `backend/app/services/employees/csv_export.rb`
- `backend/spec/rails_helper.rb`
- `backend/spec/requests/api/v1/employees_export_spec.rb`
- `backend/spec/services/employees/csv_export_spec.rb`
- `backend/spec/services/salary_revisions/create_spec.rb`
- `frontend/README.md`
- `frontend/src/features/employees/DirectoryPage.tsx`
- `frontend/src/features/salary-revisions/SalaryRevisionPage.tsx`
- `frontend/src/test/workflows.test.tsx`

Task-added files (7):

- `backend/script/local_qa_fixture.rb`
- `backend/script/prepare_test_database.rb`
- `backend/spec/safety/test_database_safety_spec.rb`
- `backend/spec/test_database_safety.rb`
- `docs/local-browser-smoke.md`
- `frontend/script/local-smoke.mjs`
- `docs/final-local-qa.md`

Overall working tree also includes the untouched pre-existing schema modification and untracked assessment audit. At final review, the tracked diff is 12 files with 309 insertions/48 deletions (including the pre-existing schema diff); there are 8 untracked files, 7 newly added by this task and the preserved historical assessment audit. Normal `git diff --stat` excludes all new files until staged; use the lists above plus `git status --short` for review. Final whitespace/source/secret-pattern/index checks are performed at teardown. No generated build/log/profile/environment files belong in the commit.

## K. Conclusion

**The corrected local MVP is ready for owner review.** All specifically authorized defects are addressed; backend/frontend suites and real-browser/full-stack checks pass with write work isolated from development. Representative long-history behavior is measured and documented without changing the contract.

The existing 10,000-employee development dataset was preserved, including its complete fingerprint and integrity results. No production or hosted resources touched. No cloud/deployment work. No dependencies installed/upgraded. G1 remains OPEN; DR-20 hosted verification and DR-22 keep their actual pending/open states. Nothing staged, committed or pushed. Temporary owned servers/browser are stopped; the user's existing local Rails/PostgreSQL remain untouched.
