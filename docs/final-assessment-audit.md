# Final assessment compliance and implementation gap audit

Date: 17 November 2026. Audited branch: `main`, HEAD `bd4e207`. **Audit only.** This report is the only repository file created or edited by this audit. Existing modifications to `backend/README.md` and `backend/db/schema.rb` are preserved. No application corrections, reseeding, resets, deployment or Git publication were performed.

## A. Executive summary

**The local MVP is substantially implemented and works on the current 10,000-employee dataset; the assessment submission is not ready.** Required deployment and video evidence are absent. Hosted database verification and owner gate sign-off remain pending. A confirmed test-environment safety hazard can expose development data to destructive spec cleanup if tests inherit the wrong environment/connection. Two frontend defects were independently confirmed: search drops keyboard focus when its debounce updates the URL, and reason-length validation rejects some strings Rails accepts.

Fresh evidence: 325 non-seed backend examples passed; 44 frontend tests passed; Ruby lint, Zeitwerk, Brakeman and the cached gem advisory scan passed. Development has 10,000 employees / 16,055 salaries, the expected seed fingerprint and 21 passing read-only integrity checks. GET-only API integration and actual Chrome UI checks passed the exercised read paths. Warm read performance was measured, including EXPLAIN ANALYZE, rather than inferred from test counts. No new data-integrity or financial-calculation failure was found in the exercised product paths.

### Authority and evidence limits

`Salary Management Assessment- Candidates(1).pdf` was not found in the repository or supplied attachment tree. The repository explicitly says the owner holds it (`.github/copilot-instructions.md:6`). The documented assessment summaries are `.github/prompts/architecture-phase.prompt.md:26` and `docs/architecture-review.md:422`; original-PDF wording, completeness and any omitted instructions remain **NOT TESTED** for every assessment row below. Do not publish the PDF without owner permission. No external assessment requirements were invented.

Priority/status definitions: **Mandatory (summary)** means reported by those assessment summaries, pending original confirmation; **Approved MVP** means the internal requirements/domain/contracts; **Optional** means polish; engineering safety/quality recommendations are identified separately. **PASS** means the stated evidence supports the stated scope, not full production certification; **PARTIAL** means an implementation/evidence limitation remains; **FAIL** means a known requirement/behavior is unsatisfied; **BLOCKED** means external authorization/decision/evidence is needed; **NOT TESTED** means no current execution evidence. Historical results are labeled explicitly.

## B. Assessment compliance matrix

All “summary” sources in this table have the original-PDF limitation above. B = backend; F = frontend. The internal MVP matrix in C provides specific implementation/test links for the broad functional rows.

| Requirement | Source / priority | Backend evidence | Frontend / artifact evidence | Tests / runtime evidence | Status | Remaining action |
|---|---|---|---|---|---|---|
| One-page product requirements | Summary; Mandatory | N/A | `docs/requirements.md` | Read product goal, persona, workflows, exclusions and success criteria; printable one-page layout not checked | PASS for document; layout NOT TESTED | Confirm original wording and export/print length if required |
| HR Manager, web salary management for 10,000 employees | Summary; Mandatory | Models, directory/revision/analytics services, seed | React routes, dashboard, directory/profile/revision | Current DB counts, GET checks, Chrome; C | PASS locally | Address findings; verify deployed instance |
| Understand organization salary distribution | Summary; Mandatory | `app/queries/analytics/summary.rb`, numeric medians | `DashboardPage.tsx`: country/department tables and statistics | RSpec analytics cases, Vitest dashboard, real seeded summary | PASS for approved distribution views | Confirm original does not require a particular visualization |
| Functional backend aligned with applied role; Rails preferred | Summary; Mandatory with Rails preference | Rails API, PostgreSQL, controllers/services/queries/serializers | Typed API integration | 325 fresh examples; actual read endpoints; earlier live revision evidence | PASS for exercised local behavior | P0-1 test safety; deployed mutation check |
| ReactJS or NextJS UI | Summary; Mandatory | N/A | Existing React/TypeScript/Vite stack and lockfile | 44 tests, typecheck, lint, build; Chrome | PASS | Fix P1-1/P1-2 |
| Relational database | Summary; Mandatory | PostgreSQL schema/FKs/CHECKs/exclusion/index | Money strings and server queries | DB integrity + constraints specs | PASS locally | Hosted compatibility remains blocked |
| Seed script with 10,000 employees | Summary; Mandatory | `db/seeds.rb`, `lib/seeds/demo_dataset.rb`, `names.rb` | Seeded rows in UI | Current counts/fingerprint/invariants; earlier full-size determinism tests | PASS for current seed | No new generator needed |
| Fully functional deployed software | Summary; Mandatory submission | No release/runtime configuration completed | No hosted application link | No deployed execution evidence | FAIL; deployment decision BLOCKED | Resolve DR-20/DR-22, deploy under separate approval and smoke-test |
| Video demonstration | Summary; Mandatory submission | N/A | No tracked video or README video link | Repository/media inspection | FAIL | Record deployed workflows and provide accessible link; duration unspecified |
| Meaningful, fast, deterministic tests | Summary; Mandatory | Rule, boundary, DB, request and concurrency specs | User workflow/API/formatter tests | 325 + 44 fresh passes; F/H limitations | PARTIAL | Safety guard, targeted regressions, durable browser evidence |
| Maintainable, readable structure | Summary; Mandatory quality | Thin controllers; one compensation formula module; query/service separation | Feature pages/shared client/query hooks | Static review and linters; no new dependency needs identified | PARTIAL | Correct confirmed defects; optional formatting/readability polish |
| Incremental Git development | Summary; Mandatory | Requirements → architecture → backend commit | Separate frontend commit | Four actual commits; no history rewrite | PASS at broad milestones; granularity PARTIAL | Preserve honest history; make future fixes focused, never fabricate old steps |
| Supporting engineering artifacts | Summary; Mandatory | Domain, schema, API, architecture/diagrams, decisions | Frontend/backend reviews, prompt/instructions | Documents read; measured performance in G | PARTIAL | Update current-state index and finalize reviewer-facing evidence |
| Intentional AI-assisted work | Summary; Mandatory | Copilot instructions, domain/trade-off/audit reports | One architecture prompt in `.github/prompts/` | Artifacts exist and explain guardrails, but no final concise implementation-use narrative | PARTIAL | Describe AI tasks, human decisions, corrections and validation; link representative actual prompts without secrets |
| Git repository / reply to original email with repository link | Register §10 / plan Phase 12; Mandatory submission per summary | Code committed through `bd4e207` | README exists; local `origin/main` label at HEAD | Local Git inspection only; no remote/email access | PARTIAL / NOT TESTED | Owner reconcile worktree, verify repository access and send final link; no email sent here |

Not established as mandatory: a specific host, deadline, video duration, salary histogram, by-level aggregate, monthly organization total, employee CRUD, full authentication, Redis, jobs, chart library, Docker or hosted CI. These must not be used to manufacture assessment failures.

## C. Approved MVP traceability matrix

Path shorthand: backend paths relative to `backend/`; frontend paths relative to `frontend/src/`. RSpec paths relative to `backend/spec/`. **R** = current GET-only Rails API/Chrome verification; **T** = fresh automated checks in H; **D** = current read-only DB verification; **HIST** = earlier execution with provenance described in H. Each PASS is limited to the evidence column.

| Requirement / source | Priority | Backend files and endpoint | Frontend files | Tests | Runtime evidence | Status / exact remaining action |
|---|---|---|---|---|---|---|
| Directory, name/ID search; requirements §MVP1 / API §1 | Approved MVP | `queries/employees/directory.rb`, `controllers/api/v1/employees_controller.rb`; GET employees | `features/employees/DirectoryPage.tsx` | `queries/employees/directory_spec.rb`, `requests/api/v1/employees_spec.rb`; `test/workflows.test.tsx` | R: count/search; T | PARTIAL: requests correct; fix search focus P1-1 |
| Country/department/status filters | Approved MVP | Same directory endpoint; `queries/param_parsing.rb` | Directory, `components/common/ReferenceFilters.tsx` | Directory request/query/filter tests, workflow tests | R: IE=8, Engineering=3000, on_leave=300 | PASS |
| Supported sort/direction and deterministic ties | Approved MVP / API §1 | Directory `SORT_COLUMNS`, `order_clause`; GET employees | Directory sort controls | Directory sort/injection/tie/paging specs; workflow tests | T; measured salary sort | PASS; do not add unsupported sort/filter fields |
| Server page/size/count and beyond-end result | Approved MVP / API §1 | Directory `page`, max100, no fetch-all | Directory pagination | Paging/empty/query tests | R: distinct 25-row pages, 10,000 total, 400 pages | PASS functional; empty display P2-1 |
| URL-backed filters/reset/preserve during navigation | Approved MVP / Phase 9 | Query parameters | Directory/profile/revision router state | Round-trip navigation and pagination RTL | T; browser query update | PASS behavior with P1-1 focus caveat |
| Identity, job/country/department/level and employment dates | Approved MVP / API §2 | Employee model/serializer; GET employee/:id | `EmployeePage.tsx` | Detail request + profile RTL | R profile | PASS |
| Current or last-held compensation, status semantics | Approved MVP / domain §5 | `employee.rb`, serializer, current salary relation | Profile/status badge, revision eligibility | Active/on_leave/terminated API/model/RTL cases | R current profile; HIST all statuses live | PASS exercised; terminated retention checked D |
| Complete newest-first history, immutable facts | Approved MVP / API §2, DR-19 | Salary model readonly guards; show history query | Profile history table, no edit/delete controls | Salary model/history/detail specs and RTL | R two-record history; D contiguous intervals | PASS for tested history; long-history stress NOT TESTED |
| Immediate revision only; no effective-date input | Approved MVP / domain §7 | `services/salary_revisions/create.rb`; POST employee/:id/salary_revisions | `SalaryRevisionPage.tsx` | Service/request cases; workflow RTL | T isolated; HIST real browser 201 | PASS; no development write performed in audit |
| Lock, current token, stale rejection and same-day microseconds | Approved MVP / DR-01/04 | Employee row lock; re-read current; one floor(6) clock read | Mandatory token, conflict lock and review/reset | `services/salary_revisions/{create,concurrency}_spec.rb`; stale RTL | T two-connection race, same-day/clock cases; HIST real409 | PASS; safeguard test execution P0-1 |
| Revision eligibility active/on_leave allowed, terminated rejected | Approved MVP / DR-03 | Employee eligibility + service validation | Profile link and direct-route guard | Service/request/model/status RTL | T; HIST live statuses | PASS |
| Decimal-string syntax, positive maximum 1,000,000,000.00 | Approved MVP / domain §4.3 | `models/salary_amount.rb`, controller structural validation | Regex string validation | Model/service/request boundaries; RTL max/invalid input | T; D finite values | PASS; no floating money math |
| Required trimmed reason 1–255 characters | Approved MVP / DR-12 | Revision reason validation and salary model | Revision reason input | ASCII/business validation tests | Ruby vs Node Unicode probe | PARTIAL: frontend UTF-16 mismatch P1-2 |
| Supported currency/frequency; no-change; usable FX | Approved MVP / DR-07/10/14 | Currency/rate lookup, no-change check, ReferenceDataQuery | Reference-based selects and field/business feedback | MissingFX/no-change/type/validation specs + RTL | T; D current currencies and frequencies | PASS |
| Atomic close/insert; rollback on any error | Approved MVP / domain §7 | Transaction, before-write validation, DB constraints | Confirmed POST success only | Rollback/failed insert/concurrency specs | T isolated; HIST exact history boundary | PASS |
| Refresh salary/history, directory and dashboard on success | Approved MVP / Phase 9 | Full confirmed POST serializer | Query cache update/invalidation and profile navigation | RTL visible result/invalidation tests | T; HIST real live revision | PASS; browser automation artifact limitation H |
| 400/401/403/404/409/422/500 contract errors | Approved MVP / API error table | `concerns/api_error_handling.rb`, controllers, DomainError | `lib/api.ts`, shared feedback, revision messages | Request robustness/auth/error specs and per-code RTL | R reads/404; T writes on disposable DB; HIST live401/403/409 | PASS for tested codes; not every production failure injected |
| Memory-only write protection, only POST header, fail closed | Approved MVP / DR-02 | Constant-time hash compare; unset key403; filter logging | `WriteKeyProvider.tsx`, context, API, forget action | Request401/403/header/log specs; RTL navigation/remount/storage | T; HIST browser key/storage/GET-header check | PASS locally; TLS/proxy enforcement BLOCKED at deployment |
| Reference data authoritative lists and has_rate | Approved MVP / API §6 | `queries/reference_data_query.rb`; GET reference_data | Shared cached hooks/selects | Reference rate/date/currency specs + loading/error RTL | R reference/filter requests | PASS |
| USD annualization, FX snapshot and per-row rounding | Approved MVP / domain §2–4, DR-05/06 | `models/compensation.rb`, numeric SQL, rate lookup | Display-only `lib/format.ts` | Ruby/SQL parity and rounding tests; formatter/API tests | T; D exact snapshots | PASS |
| Active organization totals and counts by all statuses | Approved MVP / domain §10 | `queries/analytics/summary.rb`; GET analytics/summary | `DashboardPage.tsx` | Analytics status/filter specs, dashboard RTL | R: 9200 active; USD586288203.19 | PASS |
| Country/department distributions, local-currency detail | Approved MVP / requirements §MVP2 | Summary group_stats/local_totals | Country/department tables | Analytics group/local-totals tests; RTL | R groups6/9, live dashboard | PASS; no histogram required by available sources |
| Exact numeric mean/median, groups and small samples | Approved MVP / DR-08/15 | ROW_NUMBER/COUNT/middle numeric AVG; flags | Group size/mean/median/flags/caveats | Odd/even/half-cent/duplicates/empty/large numeric cases | T; R actual summary | PASS; no client aggregation of money |
| Country/department/job-level analytics filtering | Approved MVP / DR-16 | Summary parsing/SQL; GET analytics/summary | URL analytics filters | Filter/invalid cases and RTL | R country filter; HIST livelevel | PASS; level is not directory filter |
| Empty groups, null stats and misleading-comparison caveats | Approved MVP / API §4 | Summary metrics/notes | Empty state, fixed FX, active-only/peer caveats | Empty/low-sample/error/loading RTL and specs | T; source review | PASS; human accessibility review incomplete |
| CSV matching filters/sort/direction, all rows, no paging | Approved MVP / requirements §MVP4 / API §5 | `services/employees/csv_export.rb`; GET export.csv | Export URL and reconciliation note | Export/query/sort/empty/formula specs + API/RTL URL tests | R one-row CSV; measured complete enumeration | PASS; P2-2 timestamp precision clarification |
| CSV safe text, RFC quoting, typed numeric values | Approved MVP / API §5 | Sanitizer and encoder; 18 columns | Browser download link | All documented formula/whitespace/CRLF/quote/null/empty tests | T; R real CSV | PASS tested policy; no universal spreadsheet-safety claim |
| Deterministic synthetic 10k, reference/distribution coverage | Approved MVP / requirements §MVP5 / domain §11 | `lib/seeds/demo_dataset.rb`, curated Names | Actual seeded API/UI | HIST full seed spec; current fingerprint and D | D 10000/16055, weights exact | PASS current; no audit reseed/reset |
| No gaps/overlaps, exactly one open record, valid salary/FX/FKs | Approved MVP / domain §6/13 | Schema+migrations, seed verification | Read-only history | DB constraint and revision specs | D all21 zero-violation checks; T | PASS on local14.25; hosted verification BLOCKED |
| Responsive navigation, labels, feedback, unknown route | Approved MVP / Phase 9 quality | Real API errors | Layout/common feedback/routes/CSS | Router/health/workflow RTL | Current Chrome desktop/mobile390; no runtime exceptions | PARTIAL: focus defect, broader accessibility unverified |
| Seeded-scale integration and performance | Internal plan Phase10 | Directory/analytics/CSV and indexes | Server pagination/debounce/query caching | Query count and contract tests | G current nine-case measurements +41 plans | PARTIAL: long history, concurrent load, hosted paths unmeasured |
| Supporting docs and local setup | Requirements success / Phase12 | Backend README, Makefile | Root/frontend README | Static commands review; current installed-stack runtime | Local starts pass, clean clone not performed | PARTIAL: I/J documentation/reproduction gaps |
| Deliberate exclusions remain excluded | Requirements exclusions | No CRUD/lifecycle/payroll/liveFX/auth APIs | No placeholder product pages | Routes/manifests reviewed | Source | PASS; no extra product features needed |

### Implementation-plan phase coverage

| Phase | Current audit conclusion |
|---|---|
| 1 Requirements/domain/architecture/contracts/plan | Artifacts present; original-PDF check and owner approval remain separate |
| 2 Scaffold/capability spike | Apps start and current checks pass; historical spike supports local engine only; fresh dependency installation not repeated |
| 3 Schema/constraints | Reviewed; current constraint specs/D pass. Equivalent uncommitted cast rendering noted in L; hosted/owner gate open |
| 4 Compensation/revision service | Numeric parity, validation, same-day revisions, atomicity and concurrency cases pass in isolated tests |
| 5 API/query/CSV/reference | Current specs and live reads pass; findings/limits D/E |
| 6 Seed | Existing generator and current data verified without mutation; full rerun evidence historical |
| 7 Analytics | Numeric exact median/rounding/group/filter tests pass; measured current full dataset |
| 8 Typed API/query/router/money/key state | Implemented and tested; deployment origin remains unresolved |
| 9 Workflow UI | Implemented; two confirmed UI defects and regression gaps remain |
| 10 Integration/regression/performance | Current read paths, isolated revision specs and nine benchmark cases pass; long-history/load/hosted work outstanding |
| 11 Deployment/production demo | Not implemented/verified; DR-20/G1 and DR-22/G5 open |
| 12 Final README/AI artifacts/video/email | Partial artifacts; video, deployed links, final handoff and email submission unverified/missing |

## D. Backend findings

### P0-1 — Specs can select development data and run destructive cleanup

**Evidence:** `backend/spec/rails_helper.rb:2` uses `ENV["RAILS_ENV"] ||= "test"`, then rejects production only (`:5`) and performs schema maintenance (`:13`). `backend/spec/services/salary_revisions/concurrency_spec.rb:24` calls `delete_all` on all six application models before/after each example (`:40`). Seed specs additionally contain explicit reset cases. A globally exported development environment, or a `DATABASE_URL` overriding test configuration with development, is therefore dangerous. This is a conditional, confirmed guard defect, **not evidence that current data was deleted**.

**Safe reproduction:** on the known empty disposable database only, with `PGOPTIONS='-c default_transaction_read_only=on'`, loading the helper under `RAILS_ENV=development` succeeded and reported `helper_loaded:true`, `environment:development`. No examples or cleanup ran in this probe and development was not connected by it.

**Impact:** ordinary developer environment inheritance can expose the 10,000-row development dataset to destructive tests. **Classification:** must-fix engineering/data-safety issue before submission; not an invented assessment feature.

**Proposed correction (not applied):** require test mode before environment/schema setup, and explicitly validate that the resolved database is an intended disposable test target rather than development/production/shared data. A test-mode check alone does not protect against a development `DATABASE_URL`. Keep deliberate disposable test overrides supported.

**Verification:** subprocess tests for inherited development mode and development database URL must refuse before schema/cleanup; safe isolated test configuration must still run the suite. Never reproduce cleanup against real development.

### Correctness reviewed without a new confirmed business-rule failure

The service locks the employee before current-record lookup, checks the mandatory token and eligibility, validates the decimal/reason/currency/frequency/no-change inputs, reads the clock once, chooses the effective-date FX rate, checks increasing effectivity, and closes/inserts atomically. Current specs exercise rollback, microseconds and real two-connection stale behavior. No salary arithmetic uses float in reviewed production paths. PostgreSQL analytics aggregates rounded per-employee numeric amounts and calculates exact medians; current tests include odd/even, duplicates and half-cent boundaries.

Directory SQL uses escaped bound search text and allow-listed sort expressions; JSON serializers return decimal strings and microsecond UTC timestamps. CSV is batched and formula-sanitized. The database enforces overlap, positive finite money/rates, known FKs, interval ordering and unique-open records. It does not guarantee at least one record or no gaps; seed/service/read checks establish those. Raw SQL can bypass model readonly/history guards; that is an explicitly documented boundary, not a newly discovered missing trigger requirement.

Unverified backend work: hosted major17/18 compatibility, migration/schema/seed role permissions and TLS; production proxy/log configuration; unbounded long-history behavior; latest advisory freshness. No audit migration or seed operation was performed.

## E. Frontend findings

### P1-1 — Debounced search removes keyboard focus

**Evidence:** `frontend/src/features/employees/DirectoryPage.tsx:39` keys `SearchBox` by the entire query string. At `:18` the 300ms debounce changes that string, remounting the focused input. Actual Chrome: type `ACME-00001`, await results; the URL is correct but `document.activeElement.tagName` becomes `BODY`, and the search input is no longer focused.

**Impact:** pausing while typing breaks continued keyboard entry, and every filter/page query change can discard an unsubmitted draft. **Classification:** important usability/accessibility defect in an approved workflow.

**Proposed correction:** retain the search input instance and synchronize URL/back/clear state deliberately without remounting on every debounce. Preserve the debounce and server pagination.

**Verification:** RTL/browser test must type a prefix, wait longer than debounce, assert focus remains on the searchbox, continue typing without another click, and check the final request/URL. Also cover clearing and browser history. Existing debounce test (`test/workflows.test.tsx:40`) asserts URL/request count but not focus.

### P1-2 — Reason length counts UTF-16 units instead of server characters

**Evidence:** `SalaryRevisionPage.tsx:19` uses `reason.trim().length`; Rails `services/salary_revisions/create.rb:103` uses Ruby string length. An audited example of 128 supplementary Unicode characters has JS length256 but Ruby/codepoint length128. The client rejects it as over255 although the server length rule permits it. This is a direct string-validation mismatch; no live salary write was needed to demonstrate it.

**Impact:** valid revision reasons containing supplementary Unicode characters can be blocked. **Classification:** approved-MVP validation correctness defect, P1.

**Proposed correction:** count Unicode code points consistently with Rails after trimming, while retaining the existing contract and server authority. Do not introduce a new grapheme-cluster business rule.

**Verification:** test 255/256 ASCII and supplementary-codepoint reasons at both boundaries; assert the form permits contract-valid strings and the backend agrees.

### P1-3 — Required verification work is incomplete, despite green unit totals

**Evidence:** complete history is unbounded (`backend/app/controllers/api/v1/employees_controller.rb:15`, API §2), but the current dataset's maximum is four records. Existing browser automation/results referenced in `docs/frontend-review.md:123` live only under `/tmp`; there is no repository-owned end-to-end harness covering actual APIs and the focus defect was missed. Accessibility evidence is limited to labels/focus styling/contained tables and an installed Chrome check, not a human screen-reader or multi-browser pass.

**Impact:** long-history and human keyboard/assistive workflows lack the acceptance evidence described by Phase10/quality review. **Classification:** internal-plan/quality verification gap; a particular browser tool/dependency is not a mandatory assessment requirement.

**Proposed action:** authorize an isolated long-history fixture and record actual size/query/response/render measurements; retain a reproducible minimal browser smoke procedure or script in the repository; run keyboard and assistive review. Avoid changing the approved unpaginated API without measured evidence.

**Verification:** reproduce the read/revision/403/stale/export sequence from committed instructions; exercise a recorded long-history size and keyboard continuity; retain sanitized results. No long-history fixture was created during this audit.

### P2-1 — Empty pagination reads “Page 1 of 0”

**Evidence:** directory `:58` renders page/total_pages literally; actual Chrome on `?q=NO-SUCH-EMPLOYEE` displayed `Page 1 of 0 · 0 employees`. The API correctly reports zero pages; this is presentation only.

**Impact/correction:** confusing empty results; optionally show “0 employees” and suppress the page fraction when total_pages=0. Test zero results and beyond-last-page results separately. Not a missing assessment feature.

### P2-2 — CSV timestamp precision needs explicit alignment

**Evidence:** `backend/app/services/employees/csv_export.rb:26` calls `iso8601` without a precision argument; a timestamp with `.123456` renders without the fraction. JSON uses `serializers/timestamp.rb` with `iso8601(6)`. API conventions specify microseconds, while the CSV column example itself uses whole seconds.

**Impact:** export loses subsecond precision that detail/history retains. The available CSV text is ambiguous, so this is **not classified as a proven mandatory CSV contract failure**. Clarify intended CSV precision and preferably reuse the timestamp formatter; test exact output on a fractional timestamp. No DB timestamp is altered by export.

### P2-3 — Build can succeed with an unusable missing-origin bundle

**Evidence:** `frontend/src/lib/api.ts:4` throws when imported in production without `VITE_API_BASE_URL`, but `frontend/package.json` build only runs TypeScript/Vite; configuration validation happens in browser execution rather than at build. The frontend README documents the required public variable and this audit's configured build passed. Plain build without that value is not proof of a runnable production app.

**Impact/correction:** before deployment, optionally fail the build clearly for missing/invalid public API origin and make the aggregate root check command use an explicit origin. Verify missing-origin build fails and configured preview works. This is a reproducibility/deployment safeguard, not evidence the configured local app is broken.

No new mock statistics or production mock API layer was found. Salary history remains read-only; write keys remain React memory only and are attached only to revision POSTs. All observed API requests in this audit's browser run were GET. Mobile revision at390px had no viewport overflow. Long names, maximum-value layouts, human screen-reader navigation and other browser engines were not exhaustively verified; passing basic mobile checks is not accessibility certification.

## F. Database and seed findings

Current environment: Rails `development`, `backend_development`, Unix socket, PostgreSQL14.25 Homebrew, data directory `/opt/homebrew/var/postgresql@14`. No hosted connection. All audit validation/measurement connections to it set `default_transaction_read_only=on`; existing HTTP requests were GET-only. Existing Rails startup/configuration was read rather than modified.

| Item | Actual count |
|---|---:|
| Employees / distinct employee numbers | 10,000 / 10,000 |
| Salaries / closed histories / open current-or-last-held records | 16,055 / 6,055 / 10,000 |
| Countries / departments / currencies / exchange rates | 6 / 9 / 4 / 4 |
| Active / on leave / terminated | 9,200 / 300 / 500 |
| Monthly / annual current salaries | 5,545 / 4,455 |
| Distinct fictional name pairs | 4,247 |

Country allocation: IN3200, US2800, GB1500, DE1200, FR1292, IE8. Department allocation: Engineering3000, Sales2000, Operations1393, Product900, Marketing900, Finance700, Design600, Human Resources500, Legal7. Levels1–7:1200/2000/2600/2000/1300/700/200. Current currencies: INR3162, USD2797, GBP1549, EUR2492. These match documented deterministic allocation rules; names intentionally repeat from curated fictional pools and identity is the unique employee number. Tiny groups support the low-sample demonstration. Current local-period salary values vary from843.03 to13720000.00 across different currencies/frequencies; those raw amounts are not cross-currency comparisons.

All21 current checks passed with zero violations: required open record, overlaps, gaps, pre-hire start, post-termination start, FX mismatch, termination rule, nonpositive/nonfinite/over-limit salary, invalid rates, interval ordering, reason length/trim, employee/salary/rate orphans, invalid employee fields/status/level, wrong/duplicate identifier, invalid frequency, unvalidated constraints and names outside the curated pools.

Fingerprint: `040a37bf54ff252c0fd5cae2dfe83d35c975099c817f40cb820e95c2b08b882a`, matching the previous independent seed verification. The generator uses fixed RNG20261117, anchor2026-11-01 and batched inserts inside a verification transaction. Bulk inserts bypass model callbacks but obey DB constraints and are followed by domain checks. FX lookup currently performs one lookup per generated salary record; this audit did not seed or measure seed time, and has no evidence requiring a performance refactor.

**Determinism evidence is mixed current/historical:** current canonical fingerprint matches the documented full dataset; the earlier full-size spec ran two equivalent generations and compared fingerprints. This audit deliberately did not reset, reseed or regenerate data. No claim is made that a new two-clean-database determinism run occurred here. No development rows changed during the audit.

## G. Performance measurements

Environment: Apple M1 local machine, Ruby4.0.9/Rails8.1.4.1, Homebrew PostgreSQL14.25 over Unix socket, development mode; 10,000 employees/16,055 salary records. Each case had one warm-up followed by five sequential runs with Active Record query caching disabled. Times use `Process.clock_gettime(CLOCK_MONOTONIC)` and include the query object/Ruby work specified below, not network, HTTP middleware or browser rendering. SQL notification counts exclude schema/cache events and remain constant per case. CSV timings consume the whole enumerator, not just construct it. No target latency was invented.

| Case | Min ms | Median ms | Max ms | SQL statements/run |
|---|---:|---:|---:|---:|
| Directory, page 1 / 25 | 3.207 | 5.281 | 7.677 | 2 |
| Directory, page 400 / 25 | 13.315 | 18.222 | 22.618 | 2 |
| Contains search ACME-09999 | 12.941 | 13.128 | 14.878 | 2 |
| Country IN + active filter | 2.197 | 2.241 | 2.404 | 3 |
| Annual USD salary descending | 12.429 | 13.723 | 16.243 | 2 |
| Full summary, exact medians | 47.195 | 54.017 | 60.345 | 7 |
| IN / level 4 summary | 17.030 | 18.381 | 20.994 | 8 |
| All 10,000 CSV rows, consumed | 732.430 | 743.733 | 756.187 | 11 |
| Employee 1, two history records | 2.799 | 3.058 | 3.689 | 4 |

Directory cases return their actual page records; detail includes employee/country/department/history serialization. Analytics includes all summary/group/median/local totals. Query counts are fixed rather than N+1 with page size; the filtered cases have one extra reference validation query.

41 `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` plans were captured from actual bound application SELECTs, within read-only development connections:

- First directory page uses employee-number/current-salary indexes and incremental sorting; representative page SELECT execution0.471ms.
- Contains search uses a sequential employee scan for both count and rows, filtering9,999 rows; representative statements5.624/5.619ms. At this dataset size it is not a demonstrated blocker; no trigram extension/index recommendation is justified yet.
- Last-page offset processes/sorts10,000 rows; representative page statement12.371ms versus first page0.471ms. The warm object-level medians above show the cost but do not demonstrate an assessment failure.
- Salary ordering uses an in-memory top-N sort; representative statement11.832ms. Exact organization median scans/ranks9,200 active rows; representative organization-stat query11.296ms. Full summary repeats group work in a fixed number of queries; no numeric-to-float median conversion found.
- Full CSV uses11 batched queries including the terminal empty batch; late offset batches repeat more scan/sort work (representative offset9,000 statement11.440ms). End-to-end enumeration is the slowest measured case, around744ms median. Do not replace it with fetch-all or add infrastructure without a host/load requirement.
- Captured plans reported no temporary block reads/writes at the root. This is not a claim about every workload or memory pressure condition.

Limitations: concurrent load, cold starts, full HTTP CSV transfer/stream buffering, hosted network/TLS, long-history payloads and salary-write latency/lock-contention benchmarking were not measured. Salary revision lock **correctness** was tested, not throughput. Current history maximum is four records. Phase10 remains partial; read-only measurements improve its evidence without authorizing a new fixture, index or redesign.

Raw benchmark code/results/plans are under `/tmp/acme-final-audit/`; key results are retained here so temporary-artifact loss does not erase the measurements. For durable reproducibility, retain/review a sanitized harness under a later authorized change.

## H. Automated tests, integration and evidence quality

### Commands actually run

Installed toolchain paths were explicitly prepended: `/Users/vijaypatidar/.rvm/rubies/ruby-4.0.9/bin:/opt/homebrew/bin` for Ruby and `/Users/vijaypatidar/.nvm/versions/node/v26.13.1/bin` for Node. No dependencies installed/upgraded.

| Command | Actual result / scope |
|---|---|
| `VITE_API_BASE_URL=http://localhost:3000 make frontend-check` | PASS: TypeScript, ESLint,44 Vitest tests/5 files (3.61s), configured production build87 modules; JS385.02kB/gzip117.78, CSS21.38kB/gzip5.90 |
| `RAILS_ENV=test DATABASE_URL=postgresql:///acme_seed_verification_20261117_1730 bundle exec rspec --exclude-pattern spec/lib/seeds/demo_dataset_spec.rb --seed 47214` | PASS:325 examples,0 failures,7.1s; pre-existing isolated local DB verified empty before use |
| `bin/rubocop --cache false` | PASS:82 files,0 offenses |
| `RAILS_ENV=development bin/rails zeitwerk:check` | PASS: all is good |
| `bundle exec brakeman --no-threads --quiet --no-pager --exit-on-warn --exit-on-error` | PASS report:0 errors/0 warnings. A nonfatal bundled-fileutils TypeError diagnostic was also emitted; no application security finding from it |
| `bundle exec bundler-audit check --no-update` | PASS against cached advisory DB; latest advisory freshness NOT TESTED |
| `RAILS_ENV=development bin/rails runner /tmp/acme-seed-verification/verify.rb` | PASS current21 checks/counts/fingerprint; script inspected, forces read-only and local identity guard; did not invoke seeds |
| `RAILS_ENV=development bin/rails runner /tmp/acme-final-audit/performance.rb` | PASS nine read cases/five timings each;41 read-only EXPLAIN plans |
| `python3 /tmp/acme-seed-verification/api_check.py` | PASS ten GET-only groups: directory count/search/paging/detail/history/country/status/department/reference/analytics/CSV; existing localhost API3000 |
| `VITE_API_BASE_URL=http://127.0.0.1:3000 npm run dev -- --host 127.0.0.1 --port 5173 --strictPort` | PASS temporary existing Vite startup; stopped afterward |
| `node /tmp/acme-final-audit/browser.mjs` (Node26 path above) | PASS exercised React dashboard/profile/404/mobile/required form validation; search-focus and zero-page issues reproduced; no uncaught runtime exception, no API write |
| `RAILS_ENV=development DATABASE_URL=postgresql:///acme_seed_verification_20261117_1730 PGOPTIONS='-c default_transaction_read_only=on' bundle exec ruby -I spec -r rspec/core -r ./spec/rails_helper -e '<print safe identity>'` | Helper accepted development mode; P0-1 reproduced without running any examples or writing records |
| Ruby128-codepoint reason / `Time#iso8601` probe; Node string-length probe | Reproduced UTF-16 reason mismatch and discarded CSV timestamp fractions; no DB writes |
| `git branch --show-current`; `git status --short`; `git log --oneline --decorate -15`; `git diff --check`; `git diff --cached --check` | Branch main; L shows state; whitespace PASS |

The backend test suite makes fixture writes only in the explicitly disposable test DB. No seed specs ran in this audit: their reset calls are outside the no-reset/no-reseed boundary. Earlier `FULL_SEED=1 ... --seed47214` evidence is344 examples/0 failures in25.32s, from the immediately preceding seed task; current seed source is byte-identical to audit entry. Earlier frontend review evidence includes14 actual browser checks and real successful/stale/keyless writes against a separate disposable development database; those were **not rerun against current development** here. Neither historical result is presented as a new audit execution.

Fresh tests cover meaningful rules: BigDecimal/SQL parity, exact median boundaries, strict request types, malformed input, SQL injection attempts, formula sanitization, FK/CHECK violations, stale-token/row-lock behavior, rollback, key handling/log redaction, UI errors and cache refresh. They do not merely mirror filenames. The real concurrency example uses lock observation/barriers rather than relying on an arbitrary race delay. There are23 backend spec files and5 frontend test files.

Coverage gaps/actions: test configuration safety P0-1; focus-continuation P1-1; Unicode reason boundaries P1-2; zero-page text; CSV fractional timestamp intent; long-history performance; durable real-API browser procedure; human accessibility; fresh-clone install; hosted compatibility/TLS/proxy logs. Frontend fetch mocks validate UI behavior but do not prove deployed connectivity. No coverage percentage was measured, and44/325 counts must not be interpreted as exhaustive correctness.

Audit tool failures were corrected without repository changes: parallel log commands initially raced the temporary-directory creation and were rerun; Ruby4 has no bundled `benchmark` here, so the temporary benchmark switched to the built-in monotonic clock without installing a gem; the first standalone helper probe omitted `rspec/core` and was rerun with it. These were audit-harness issues, not application defects. No final listed check remains failed except the intentional defect probes and unavailable submission evidence.

## I. Documentation, security and Git history

### Documentation/artifact review

The product goal, persona, exclusions, monetary/FX/status/history rules, diagrams, API shapes, gate register and testing instructions are documented. Architecture includes component/data-flow and entity diagrams; domain/architecture notes explain exact numeric median, rounding order, cross-currency separation, last-held salary and unbounded history trade-offs. Prompt/instructions provide evidence of intentional AI use, but a final owner-reviewed narrative tying implementation assistance to verification is still missing (B).

**DOC-1, P1 submission-documentation gap:** `README.md:10` links the implementation reviews but no final assessment, deployment/demo/AI-use/performance handoff. `docs/api-contracts.md:4` still says DB tests could not run in the audit, and `docs/implementation-plan.md:4` retains the earlier blocked implementation state; historical reports are legitimate but current readers must reconcile them manually. Proposed action: add a concise current-state/evidence index, date/scope the historical statuses, link this audit/hosted evidence once it exists, and retain G1/DR-20/DR-22 unchanged until genuinely resolved. Verify all reviewer-facing links and commands. This does not authorize rewriting approved domain rules or falsifying prior gate status.

**DOC-2, P2 local-run clarity:** root `README.md:34` lists sequential `cd backend` / `cd frontend` lines without explicitly saying separate terminals and does not introduce the write key; the detailed frontend README does. Backend README's initial run block also shows server start before its later key explanation. The app correctly returns403 without the key, but a reviewer following only the root block cannot demonstrate a write. Proposed action: link a single clear local procedure with separate terminals, safe seed prerequisites and private key entry; verify on a clean checkout. No defect in the fail-closed policy is implied.

Fresh-clone dependency installation was not attempted (audit forbids installing dependencies); installed-lock toolchain runs pass. Node/npm versions appear in prose but no `.nvmrc` or package engines entry is present; optionally pin the documented Node version for easier reproduction. No formatter requirement, new dependency or hosted CI requirement was inferred. Compressed long JSX/CSS lines make review harder in some feature files; improving wrapping is optional maintainability polish, not a reason to rewrite working components in this audit.

### Git history and working tree

Actual history, four commits:

1. `afe107c docs: add one-page product requirements`
2. `5c818dc docs: define architecture and compensation domain rules`
3. `08ef57b feat: complete backend MVP and project scaffolding`
4. `bd4e207 feat: implement complete salary management frontend MVP`

Backend, seed, frontend and principal design reports are committed. Milestones are meaningful, although the backend/scaffold and frontend commits are broad rather than the per-workflow increments suggested by the plan. Do not rewrite history or invent development chronology. `origin/main` locally points atHEAD; no remote fetch/public-access check was performed, so this is not a fresh assertion of reviewer access or successful final submission.

Two pre-existing unstaged modifications are not yet in a future clean submission: backend README's recent local seed evidence and two equivalent array-cast renderings in schema. The latter change preserves status/frequency values and is not an identified business-rule change. Owner should review and deliberately include/exclude them later. This audit adds only its report and does not stage anything. No required implementation files are currently untracked.

### Security review

No tracked real `.env`, `.env.local`, master key, node_modules, dist or coverage files were found. Root/backend/frontend ignore rules protect local environment/key/log/generated paths; safe examples use a public localhost origin/comments/placeholders. `backend/config/credentials.yml.enc` is encrypted and tracked, with no tracked master key; decryption was not attempted. A credentialed-URL pattern matched only the generic commented example in `config/database.yml`, not a live credential. No secret values were printed.

Tracked-source and252 text-blob history scans found no private-key, common AWS/GitHub/OpenAI token patterns; this is evidence of the scan scope, not a guarantee that every possible secret format is absent. Test authorization literals are clearly synthetic fixtures. Generated build artifacts/logs/browser profiles stay ignored or under `/tmp`; no browser artifacts belong in the commit.

Production limitations are tracked as deployment work: `backend/config/environments/production.rb:22` / `:25` leave proxy SSL assumptions/force_ssl commented, and production host policy is unset; default production CORS permits no origin. Those are reasonable fail-closed/incomplete deployment defaults, not proof of a live insecure deployment. Before release, select the topology, enforce HTTPS/proxy trust, verify key protection and redaction at application **and proxy** layers, and test configured CORS. No invented authentication/RBAC requirement is proposed.

## J. Deployment and video readiness

| Submission work | Current evidence/status | Exact remaining action / verification |
|---|---|---|
| DR-20 hosted PostgreSQL | Neon selection documented, hosted extension/exclusion/role/TLS checks absent: BLOCKED | Under separate authorization run register§12.5 on a disposable hosted target; record PG/version/role, adjacent interval success, overlap rejection, Rails TLS; verify migrations/schema/seed separately |
| G1 sign-off | OPEN | Owner reviews delegated decisions and hosted evidence; do not auto-close |
| DR-22 application host/topology | OPEN; no selected deployment implementation | Owner choose host/origin routing/release commands and production use/configuration of rack-cors |
| API/frontend deployment | No deploy artifact, verified URL or README link: FAIL requirement | Configure approved host, public build origin, secrets, SPA route fallback, Rails runtime, DB pool and release/migration path; do not assume a specific provider or require Docker |
| Production security/data smoke | NOT TESTED | HTTPS/read-only/write-key checks,403 unconfigured instance,401 wrong/missing, valid immediate revision/history, CORS, CSV, sanitized500/logs, exactly10k synthetic rows and invariants |
| Demo video | No repository media or README link: FAIL requirement | Record deployed directory/search/profile/history/revision/dashboard/export with synthetic data; distribute key privately, not on screen or in repo; original duration unspecified |
| Final artifacts and email | PARTIAL / NOT TESTED | Link live app, video, AI narrative, reproducible setup/tests and audit/performance; verify repo accessibility; owner replies to original email with repo link |

A private/unlinked deployment or video outside this workspace cannot be ruled out; it is absent from the available submission evidence. No resource creation, deployment, hosted connection, video recording or external message was attempted.

## K. Prioritized action plan

| Priority / ID | Work and evidence | Mandatory vs optional | Proposed verification |
|---|---|---|---|
| P0-1 | Protect test environment/database before cleanup; D | Must fix engineering data-safety hazard | Reject development/shared URL before DB/schema/fixtures; safe isolated suite passes |
| Submission S1 | Obtain private access to original assessment and cross-check summary; A/B | Required evidence validation, original not published automatically | Mark each summary row confirmed/amend unknown wording |
| Submission S2 | Resolve hosted DR-20 evidence and owner gate review; J | Internal release prerequisite | Role/TLS/extension/exclusion/migration/seed checks; owner sign-off |
| Submission S3 | Resolve DR-22, deploy API and SPA, perform production smoke; J | Reported explicit assessment requirement | Working public/reviewer URL and full read/write/history/export verification |
| Submission S4 | Record/link demo video and final handoff; J | Reported explicit assessment requirement | Reviewer can access video/repo; live workflows and private key delivery verified |
| P1-1 | Preserve search focus/draft across debounce; E | Approved workflow usability correction | Pause/continue keyboard typing, URL/history/reset regression |
| P1-2 | Match Unicode reason count to Rails; E | Approved validation correction |255/256 codepoint boundaries including supplementary characters |
| P1-3 | Long-history measurements and durable browser/keyboard/accessibility checks; E/G/H | Internal-plan/quality evidence gap, not a new product feature | Record fixture size and timings on authorized disposable DB, repeatable browser procedure and human keyboard/assistive pass |
| DOC-1 | Current evidence index, AI-use narrative, submission links and stale status labels; I | Reported artifact requirement/internal handoff | Consistent dated claims, original-PDF traceability and working links |
| Git handoff | Owner review existing README/schema changes and audit, make honest focused commits | Submission hygiene | Clean reviewed tree, no secrets/generated output, remote reviewer access |
| P2-1 | Empty pagination text | Optional polish | Zero matches and beyond-last page both clear |
| P2-2 | Clarify CSV timestamp precision, then test agreed format | Optional contract-consistency polish pending clarification | Fractional timestamp export exact per agreed rule |
| P2-3 / DOC-2 | Build-origin guard, clear root startup/key flow, optional Node pin | Optional developer-experience safeguards; correct deployment env itself mandatory | Missing origin clearly rejected; clean documented startup works |
| P2 readability | Wrap dense JSX/CSS only when separately authorized | Optional maintainability polish | No behavior change, lint/tests remain green |

No evidence currently justifies Redis, jobs, caching, a new chart package, trigram indexing or database redesign. Salary bands/compa-ratios/pay-equity conclusions, lifecycle CRUD, full auth and monthly/by-level aggregate endpoints remain excluded or unsupported optional scope, not missing MVP work.

## L. Final Git status and audit boundary

Branch `main`; HEAD remains `bd4e207`. At entry: two unstaged modifications (`backend/README.md`, `backend/db/schema.rb`), no staged changes, no untracked implementation files. At completion:

```text
 M backend/README.md
 M backend/db/schema.rb
?? docs/final-assessment-audit.md
```

Only `docs/final-assessment-audit.md` was added by this audit. The two existing tracked modifications retain their entry bytes. Tracked `git diff --stat` remains two files,47 insertions/6 deletions; it excludes this new report until staged. The report contains the current measurements/findings and is intentionally untracked for owner review. Entry index and all tracked source/document hashes are compared at teardown; whitespace checks pass.

Development data fingerprint/counts are rechecked at completion. No application source, test or existing architecture/documentation was edited; no frontend/backend features, migrations, seeds, reset/drop commands or dependency changes were made. Existing development data was read only; fixture mutation occurred only in the pre-verified disposable test DB under the explicitly allowed test checks. Owned Vite/isolated Chrome processes are stopped; the user's existing Rails/PostgreSQL services are left running.

**G1 remains OPEN. DR-20 hosted verification and DR-22 remain in their documented states. No production data or cloud resources touched. Nothing staged, committed or pushed.** This is an actionable audit, not an authorization to implement its recommendations or a certification that the assessment is complete.
