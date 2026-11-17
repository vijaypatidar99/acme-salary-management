# Assessment Requirement Validation Report

**Report type:** Independent compliance audit — read-only  
**Date:** 17 November 2026  
**Auditor role:** Senior Software Architect / Principal Engineer / QA Lead / Technical Assessment Reviewer  
**Repository branch:** `main` HEAD `08baae0`  
**PDF status:** `Salary Management Assessment- Candidates(1).pdf` was supplied as an attachment but is not available in the workspace file tree. Assessment requirements are evaluated from the reproduction in the audit prompt, corroborated by `.github/copilot-instructions.md`, `docs/architecture-review.md`, and `.github/prompts/architecture-phase.prompt.md`. Original PDF wording remains **NOT INDEPENDENTLY READ** from the file; discrepancies between the reproduction and the original PDF cannot be ruled out.

> **IMPORTANT:** This report does not implement fixes, modify source code, alter documents, reseed data, deploy, or rewrite Git history. It identifies what is complete, what is incomplete, and what must happen before submission.

---

## 1. Executive Summary

### Overall Requirement Compliance Verdict

**7 of 9 explicit mandatory assessment requirements are PASS or PARTIAL locally. 2 are hard FAIL.**

The two hard failures are both submission-blocking: **no deployed application exists** and **no demo video exists**. Every functional requirement is locally satisfied or has only minor partial evidence gaps. The core Rails/React/PostgreSQL full-stack is implemented and locally verified against 10,000 synthetic employees. Database integrity, financial calculations, concurrency, and test safety are all substantively correct.

### Application Functionality Verdict

**FUNCTIONALLY COMPLETE locally.** All five product workflows (directory, profile, salary revision, analytics, CSV export) are implemented and locally verified.

**Analytics cross-check (independently run this audit):**
- Naive SUM without per-row rounding: $586,288,203.26 — intentionally not matching Rails
- Per-row `ROUND(annual × fx_rate, 2)` then SUM: **$586,288,203.19** — matches Rails exactly ✓

The rounding is correct per DR-06 and the `Compensation` module. No financial correctness defect found.

### Submission Readiness Verdict

**NOT READY — SUBMISSION REQUIREMENTS PENDING**

The application is functionally complete and locally verified. It cannot be submitted because:
1. No publicly accessible deployed application exists (P0)
2. No demo video exists (P0)
3. `backend/db/schema.rb` has an uncommitted modification — dirty working tree (P0)
4. The Git history has only 5 coarse commits, all on a single day (P2)

### Counts

| Category | Count |
|---|---|
| Mandatory assessment requirements PASS | 5 |
| Mandatory assessment requirements PARTIAL | 2 |
| Mandatory assessment requirements FAIL | 2 |
| Mandatory assessment requirements UNVERIFIED | 0 |
| Total explicit mandatory requirements | 9 |
| P0 blockers | 3 |
| P1 issues | 2 |
| P2 improvements | 4 |
| P3 optional | 1 |

---

## 2. Original Assessment Requirements Matrix

The following 9 requirements are explicitly stated in the original assessment. Engineering quality expectations and documentation artifacts are assessed separately in §4–§9.

| ID | Original requirement | Status | Implementation evidence | Test / verification evidence | Gap | Priority |
|---|---|---|---|---|---|---|
| R-01 | Build employee salary management software for 10,000 employees | **PASS** | Rails API + React SPA + PostgreSQL; seed creates exactly 10,000 synthetic employees across 6 countries, 9 departments, 3 statuses, 4 currencies | DB verified this audit: 10,000 employees / 16,055 salary records / 10,000 open records; all integrity checks zero; analytics org total $586,288,203.19 confirmed | None | — |
| R-02 | One-page requirements document before building | **PASS** | `docs/requirements.md` — 32 lines; goal, primary user, 5 MVP workflows, deliberate exclusions with reasons, key assumptions, success criteria | First commit `afe107c` at 12:18 IST before any code commit at 16:42 IST | No print/layout format requirement in PDF; content is substantively complete | — |
| R-03 | Backend using a suitable language/framework | **PASS** | Rails 8.1 API-only; PostgreSQL; thin controllers, service objects, query objects, serializers, full error handling | 358 RSpec examples (documented prior run); independently verified DB, routes, services, constraints | — | — |
| R-04 | ReactJS or NextJS frontend | **PASS** | React 19 + TypeScript + Vite; TanStack Query; feature-based structure; real API calls; no mock-only screens | 55 Vitest tests (documented prior run); real browser smoke documented in `docs/final-local-qa.md` | — | — |
| R-05 | Relational database | **PASS** | PostgreSQL; foreign keys, CHECK constraints, EXCLUSION constraint (btree_gist), partial unique index, indexes on all FK columns | Schema read-verified; 7 database constraint spec groups; all constraints independently confirmed | `btree_gist` on hosted Neon not yet verified (DR-20 open) | — |
| R-06 | Seed script with 10,000 employees | **PASS** | `db/seeds.rb` → `lib/seeds/demo_dataset.rb`; deterministic (fixed RNG seed 20261117, fixed anchor date); RESET=1 guard; production guard; 7-invariant post-seed verify | DB counts independently confirmed this audit: 10,000/16,055/10,000 open; 0 overlaps/gaps/FX mismatches; country×6, dept×9, currency×4 | Exactly 10,000 employees ✓ | — |
| R-07 | Fully functional deployed software | **FAIL** | No deployment configuration, no Dockerfile, no Procfile, no cloud provider config file; `production.rb` present but SSL/host config is commented out; `CORS_ALLOWED_ORIGINS` env documented but not set | No hosted URL in README or any doc; README explicitly states "No hosted CI or deployment is configured. G1 remains OPEN" | **P0 BLOCKER — deployment has not occurred** | P0 |
| R-08 | Video demonstration of the software | **FAIL** | No video file in repo; no video link in README or any document; no reference to a hosted video platform | File search found zero video files; README search found no video URL | **P0 BLOCKER — no demo video exists** | P0 |
| R-09 | Use agentic AI tools intentionally | **PARTIAL** | `.github/copilot-instructions.md` (65 lines of guardrails); `.github/prompts/architecture-phase.prompt.md` (297 lines); AI use narrative in README "AI-assisted development" section | Artifacts describe which decisions were delegated vs owner-approved; no attached actual session transcripts | AI use documented at high level but specific prompt examples and output verification not concretely linked | P2 |

---

## 3. Product Functionality Validation

### 3.1 Employee Directory — PASS

| Feature | Implementation | Evidence | Status |
|---|---|---|---|
| Paginated employee list | `Employees::Directory`, `GET /api/v1/employees` | DB: 400 pages of 25 at 10,000 total | PASS |
| Search (name, ID) | ILIKE on first/last/combined/employee_number; `%`, `_`, `\` escaped | Directory query spec; SQL ESCAPE clause | PASS |
| Country / department / status filters | `scope.where()` on each | Filter spec; R: IE=8, Engineering=3,000, on_leave=300 | PASS |
| Sorting (8 columns, allow-listed) | `SORT_COLUMNS` hash; SQL never interpolates user input | Directory sort/injection/tie spec | PASS |
| Stable ordering | All sorts append `employees.id ASC` | Tie-breaking spec | PASS |
| Server-side pagination | `limit/offset`; `MAX_PER_PAGE=100`; never loads all 10k into React | Returns `total_count`, `total_pages` | PASS |
| URL state sync | `useSearchParams` backs all filters; page resets on filter change | Vitest workflow test | PASS |
| Search debounce (300ms) | `SearchBox` with `useRef` timer; retains draft on other filter changes | Vitest focus/debounce test | PASS |
| Search focus retention | Fixed in `08baae0`; input instance persists through URL changes | Vitest keyboard/back/forward test | PASS |
| Empty state | No employees message on zero results; "first page" recovery link | Vitest empty test | PASS |
| Invalid params | Allow-listed; `invalid_parameter` DomainError for bad sort/status | Robustness spec | PASS |
| CSV export link | `api.exportUrl(params)` excludes page/per_page; same filters | Frontend workflow test | PASS |

No N+1 queries: directory uses one SQL join (employees + country + department + current salary). Count is a separate filter-only query. `each_batch` streams CSV without loading full dataset into memory.

### 3.2 Employee Profile — PASS

All profile fields verified: identity (name, number, job title, level), country, department, employment status with badge, hired/terminated dates, current or last-held salary (amount, currency, frequency, effective_from, annual base local and reporting), and complete salary history newest-first. FX rate snapshot stored at revision time — never recomputed. Terminated employees show "Last salary held" with note. `can_revise_salary` gates the "Revise salary" button.

### 3.3 Salary Revision — PASS for all core rules

| Rule | Implementation | Test | Status |
|---|---|---|---|
| Write-key fail-closed | Constant-time SHA256 compare; unset = 403 `writes_disabled` first | Request auth/403/401 spec; Vitest write-key nav | PASS |
| Positive amount ≤ 1,000,000,000.00 | `SalaryAmount.errors_for`; BigDecimal; no float | 10 boundary/format cases | PASS |
| Required trimmed reason 1–255 codepoints | Ruby `strip`; NUL rejection; codepoint length | 8 boundary cases incl. 255-emoji | PASS |
| Currency must have FX rate | `ExchangeRate.lookup` → nil = `missing_exchange_rate`; never defaults to 1 | Missing-rate spec | PASS |
| No-change rejection | Amount + currency + frequency all unchanged | no_change spec | PASS |
| Stale token concurrency guard | `expected_current_salary_record_id` checked after row lock | Stale token spec; 2-thread PG lock concurrency spec | PASS |
| Employee row lock before salary read | `Employee.lock.find` then salary read | SQL subscriber ordering test | PASS |
| Clock read exactly once | Injectable `clock`; `FixedClock` raises if called >1 | Clock count assertion | PASS |
| Previous record preserved; only `effective_to` updated | `attr_readonly` on salary facts; `closed_interval_is_immutable` | History immutability spec; `preserve_history` before_destroy | PASS |
| New record created with same timestamp | `close_and_insert` uses one `effective_at` | Same-microsecond spec | PASS |
| Atomic transaction; rollback on error | `Employee.transaction`; rescue rolls back | Failed-insert rollback spec | PASS |
| DB exclusion/unique catches races | `rescue ActiveRecord::ExclusionViolation` → `revision_conflict` | DB constraint spec; concurrency spec | PASS |
| Frontend: no financial arithmetic | Regex/string validation only; `format.ts` is display only | Code review | PASS |
| Stale conflict UX | Shows latest salary; "Review and reset" button | Vitest stale/conflict test | PASS |
| Cache invalidation on success | Invalidates `['employees']`, `['analytics']`, `['employee', id]` | Vitest revision success test | PASS |

**Analytics exclusion:** Only `active` employees counted (`WHERE e.employment_status = 'active'` in `active_population_sql`). `on_leave` allowed to revise salary; `terminated` correctly rejected.

### 3.4 Compensation Analytics — PASS

| Feature | Implementation | Verification |
|---|---|---|
| Active headcount | SQL `employment_status = 'active'` join | DB: 9,200 ✓ |
| Org total annual USD | Per-row `ROUND(annual_local × fx_rate, 2)` then SUM | DB cross-check: $586,288,203.19 ✓ |
| Average annual USD | `ROUND(AVG(annual_reporting), 2)` | Analytics spec |
| Exact numeric median | `ROW_NUMBER/COUNT` window + `AVG FILTER WHERE rn IN ((n+1)/2, (n+2)/2)` — no `percentile_cont`, no float | Analytics odd/even/half-cent spec |
| Country breakdowns with local-currency totals | `group_stats("e.country_code")` + `local_totals` | 6 countries × 4 currencies |
| Department breakdowns | `group_stats("e.department_id")` | 9 departments |
| All statuses in `status_counts` | `index_with { 0 }` baseline ensures zeros | active/on_leave/terminated all present |
| Analytics filtering | Country / department / job_level via sanitized SQL | Filter spec |
| `low_sample` flag (< 10 employees) | Headcount < `LOW_SAMPLE_THRESHOLD = 10` | IE=8, Legal dept both flagged |
| Monthly-to-annual conversion | `CASE pay_frequency WHEN 'monthly' THEN 12` | Ruby/SQL parity spec |
| Inactive employees excluded from pay totals | `active_population_sql` WHERE clause | — |
| Notes and caveats | Fixed array rendered in dashboard | UI review |

### 3.5 CSV Export — PASS

Streamed (not buffered); 18 columns per API contract; respects active directory filters; `each_batch(1000)` exports all matching rows; formula injection mitigated (prefix `'` for risky text); RFC 4180 quoting; verbatim numeric/date values; UTC microsecond timestamps via `Timestamp.call` (fixed in `08baae0`); deterministic order. Export URL construction excludes `page` and `per_page` correctly.

---

## 4. Backend and Database Assessment

### 4.1 Strengths

- **Money arithmetic:** `BigDecimal` throughout Ruby; `numeric` in PostgreSQL; no float casts anywhere. `Compensation` module is the single formula definition with SQL twin. Ruby/SQL parity spec-covered.
- **Database constraints:** EXCLUSION constraint (`btree_gist`) prevents overlapping salary intervals. Partial unique index prevents two open records. CHECK constraints enforce: amount > 0, fx_rate > 0, NaN rejection, pay_frequency enum, reason non-blank, interval ordering, status values, terminated_on rule, job level 1–7. All foreign keys present.
- **Transaction safety:** Salary revision runs in one `Employee.transaction`; row lock acquired before any salary read; clock read once after lock; FX lookup uses that one UTC date; `close_and_insert` closes first (no overlap at insert time under exclusion constraint); both `ExclusionViolation` and `RecordNotUnique` caught and mapped to `revision_conflict`.
- **Concurrency:** Two-thread real PostgreSQL concurrency test validates serialization; stale token is the application-level idempotency guard.
- **Error handling:** Every endpoint has `rescue_from` coverage; no SQL, constraint, or table names leak in 500 responses. Write-key never logged or echoed.
- **CORS:** `config/initializers/cors.rb` refuses wildcard `*`; in development allows Vite `localhost:5173`; in production reads `CORS_ALLOWED_ORIGINS` env variable; empty in production = no allowed origins (fail-safe).
- **Seed safety:** `guard_production!` blocks production seed without `ALLOW_PRODUCTION_SEED=1`; idempotent; `RESET=1` explicit flag; 7-invariant post-seed verify rolls back on failure.
- **N+1 prevention:** Directory joins country, department, and current salary in one SQL query. Analytics uses CTEs with window functions.

### 4.2 Defects and Issues

| ID | Severity | Issue | Evidence | Recommended Fix |
|---|---|---|---|---|
| BE-01 | **P0** | `backend/db/schema.rb` modified but not committed | `git status --short`: ` M backend/db/schema.rb` | `git add backend/db/schema.rb && git commit -m "chore: sync schema.rb"` |
| BE-02 | **P1** | Production `config.force_ssl` and `config.assume_ssl` commented out in `production.rb` | `config/environments/production.rb` | Uncomment appropriate SSL config before or immediately after deployment |
| BE-03 | **P2** | No `config.hosts` configured for production — DNS rebinding protection disabled | `production.rb` | Set `config.hosts` to deployed backend hostname |
| BE-04 | **P1** | `btree_gist` PostgreSQL extension not verified on Neon Free plan | DR-20 open; copilot-instructions.md line 20 | Test `CREATE EXTENSION btree_gist` on Neon before migration |
| BE-05 | **P3** | Analytics `status_counts` runs a separate Ruby-side query outside main CTE | `summary.rb` line 113 | Minor: extra query; not a correctness issue |

---

## 5. Frontend Assessment

### 5.1 Strengths

- **TypeScript types:** `src/types/api.ts` covers every API shape; strongly typed.
- **TanStack Query:** All server state uses `useQuery`/`useMutation`; cache invalidation on revision success covers employees list, analytics, and the specific employee.
- **URL state:** `useSearchParams` drives all directory and analytics filters; browser Back/Forward works.
- **Write-key security:** `WriteKeyProvider` stores key in React `useState` only; never persisted to `localStorage`/`sessionStorage`; cleared on invalid-key response or reload.
- **Money display only:** `format.ts` formats decimals for display; no arithmetic, no currency comparison, no aggregation in the browser.
- **Error states:** Every data-fetching component shows `ErrorPanel` with retry; every mutation error maps to a user-readable message per specific API error code.
- **Accessibility:** `<label>` wraps all inputs; `aria-invalid`, `aria-describedby` on form fields; `role="alert"` on error messages; `role="status"` on success notice; `<caption>` on tables; scrollable regions have `tabIndex={0}` and `aria-label`.

### 5.2 Defects and Issues

| ID | Severity | Issue | Evidence | Fix |
|---|---|---|---|---|
| FE-01 | **P2** | `frontend/dist/` (Vite build output) is tracked in Git | Repo structure: `frontend/dist/assets/`, `frontend/dist/index.html` | Add `frontend/dist/` to `.gitignore`; `git rm -r --cached frontend/dist/` |
| FE-02 | **P2** | Unicode reason validation uses JS codepoint counting which may differ from Ruby's `String#length` for composed grapheme clusters | `SalaryRevisionPage.tsx` comment notes the limitation | Rails is authoritative; edge case only for unusual grapheme clusters — documented and acceptable |

---

## 6. Testing Assessment

> **IMPORTANT — Test safety restriction:** Tests were not re-run during this audit. The test database safety mechanism (`TestDatabaseSafety`) requires an explicitly attested disposable local PostgreSQL database. Running tests against `backend_development` is explicitly forbidden. Re-running tests requires `script/prepare_test_database.rb` → source the generated env file → `FULL_SEED=1 bundle exec rspec`.

### 6.1 Backend Tests — Previously verified: 358 examples, 0 failures

| Area | Spec file | Assessment |
|---|---|---|
| Salary revision service | `services/salary_revisions/create_spec.rb` | 30+ cases: timestamp, history preservation, stale token, all validation fields, rollback, invariant guard, UTC timezone edge case, clock ordering |
| Concurrency | `services/salary_revisions/concurrency_spec.rb` | Real two-connection PG lock test — not a mock |
| Analytics summary | `queries/analytics/summary_spec.rb` | Org totals, filters, money string format, low-sample threshold |
| Employee directory | `queries/employees/directory_spec.rb` | Pagination, search, filters, sort, injection prevention |
| Database constraints | `spec/db/constraints_spec.rb` | 15+ cases testing DB directly with `insert_all!` bypassing validations: exclusion, partial unique, CHECK, FK, NaN, range |
| CSV export | `services/employees/csv_export_spec.rb` | Formula injection, RFC quoting, batch streaming, timestamp precision |
| Request specs | `requests/api/v1/` | employees, analytics, export, reference_data, salary_revisions, robustness, CORS, health, unknown routes |
| Test database safety | `spec/safety/test_database_safety_spec.rb` | 6 database-free subprocess cases |
| Model specs | `models/` | Compensation parity (Ruby/SQL), decimal_string, salary_amount boundaries, employee validations, salary_record immutability |
| Seed | `spec/lib/seeds/demo_dataset_spec.rb` | Determinism and invariant verification |

**Missing test gaps (non-blocking):**

| Gap | Priority |
|---|---|
| `ReferenceDataQuery` — no dedicated spec | P2 |
| Analytics `by_country` and `by_department` separate group specs minimal | P3 |

### 6.2 Frontend Tests — Previously verified: 55 tests, 0 failures

Coverage: employee directory (search, filters, URL sync, debounce, focus, back/forward, draft retention, pagination, empty state), employee profile, salary revision (form submission, validation, success refresh, stale conflict, write-key clearing), dashboard analytics, API client, router.

### 6.3 Test Database Safety

The safety mechanism is substantive and correctly implemented:
- `TestDatabaseSafety.configure!` runs before Rails boot
- Requires `ACME_TEST_DATABASE` name + `ACME_TEST_DATABASE_TOKEN` (64-hex)
- Checks `pg_database` comment must equal `acme-rspec-disposable:<token>`
- PostgreSQL adapter factory opens each connection read-only until identity is verified
- Explicitly blocks `backend_development`, `backend_production`, `postgres`, `template0`, `template1`
- `script/prepare_test_database.rb` creates a fresh named DB, sets disposable marker, loads schema, prints path to a 0600 temp env file

**Assessment: The test safety implementation is a genuine production-quality guard, not theater.**

---

## 7. Seed Data Verification

**All queries run directly against `backend_development` as read-only during this audit.**

| Metric | Expected | Independently verified | Match |
|---|---|---|---|
| Employee count | 10,000 | **10,000** | ✓ |
| Salary records | — | **16,055** | ✓ |
| Open (current) salary records | 10,000 | **10,000** | ✓ |
| Countries | 6 | **6** (IN, US, GB, DE, FR, IE) | ✓ |
| Departments | 9 | **9** | ✓ |
| Currencies | 4 | **4** (USD, EUR, GBP, INR) | ✓ |
| Employment statuses | 3 | **3** (active, on_leave, terminated) | ✓ |
| Active employees | ~9,200 | **9,200** | ✓ |
| Employees without exactly 1 open record | 0 | **0** | ✓ |
| Overlapping salary intervals | 0 | **0** | ✓ |
| Gaps between consecutive salary records | 0 | **0** | ✓ |
| FX rate mismatches | 0 | **0** | ✓ |
| Analytics org total (per-row rounding) | — | **$586,288,203.19** | ✓ Matches documented value |

**Seed determinism:** Fixed `Random.new(SEED)` with `SEED = 20_261_117` and `ANCHOR_DATE = Date.new(2026, 11, 1)`. SHA256 fingerprint: `040a37bf54ff252c0fd5cae2dfe83d35c975099c817f40cb820e95c2b08b882a`.

---

## 8. Performance Assessment

All measurements are from documented local runs (`docs/final-local-qa.md`); no hosted benchmarks available.

| Scenario | Assessment |
|---|---|
| Directory page (25 from 10,000) | Single join query with LIMIT/OFFSET; indexed on employee_number, country_code, department_id — adequate |
| Search ILIKE | No index on names; sequential scan at 10,000 rows — acceptable; would need GIN/trgm at millions |
| Analytics summary | CTE with window functions in one query; no Ruby-side aggregation — efficient |
| CSV export | `each_batch(1000)` streaming; no full dataset in memory — correct |
| Salary history | `salary_records.newest_first.to_a` — no pagination; seed max ~4 records; 1,000-record QA fixture rendered in ~397ms |
| `status_counts` | Separate query in analytics; minor extra round-trip; not N+1 |

**Index coverage verified:** employee_number (unique), country_code, department_id, partial unique on salary_records (effective_to IS NULL), exclusion constraint index, exchange_rates lookup unique index.

**Missing index:** No index on `employees.employment_status`. Analytics `WHERE employment_status = 'active'` is a sequential scan at 10,000 rows — acceptable for assessment scale.

---

## 9. Git History and AI Artifacts

### 9.1 Git History

```
afe107c  docs: add one-page product requirements           (Tue Nov 17 12:18 IST)
5c818dc  docs: define architecture and compensation domain rules (Tue Nov 17 13:48 IST)
08ef57b  feat: complete backend MVP and project scaffolding (Tue Nov 17 16:42 IST)
bd4e207  feat: implement complete salary management frontend MVP (Tue Nov 17 17:28 IST)
08baae0  fix: finalize MVP quality improvements and test safety (Tue Nov 17 18:23 IST)  ← HEAD
```

**Assessment:** 5 commits on a single day. The sequence is logically correct (requirements → architecture → backend → frontend → fixes) and commit messages accurately describe the changes. However, all commits are from one day — this does not demonstrate incremental development over time. The assessment asks for "meaningful incremental development history."

**Git status:** `M backend/db/schema.rb` — dirty working tree. This must be committed before submission.

**No sensitive credentials found in commit history.** Remote: `git@github.com:vijaypatidar99/acme-salary-management.git` — public access unverified from this audit.

### 9.2 AI Development Artifacts

| Artifact | Location | Quality |
|---|---|---|
| Copilot guardrails | `.github/copilot-instructions.md` (65 lines) | High — covers domain rules, money safety, security, testing, Git honesty |
| Architecture prompt | `.github/prompts/architecture-phase.prompt.md` (297 lines) | High — detailed domain/architecture instructions |
| AI use narrative | `README.md` §"AI-assisted development" | Adequate — describes Codex involvement, human decisions, corrections |
| Domain decisions | `docs/domain-decisions.md` | Trade-offs documented with DR numbers and rationale |
| Architecture review | `docs/architecture-review.md` | Decision register with approval status |
| Audit reports | `docs/final-assessment-audit.md`, `docs/final-local-qa.md`, `docs/local-browser-smoke.md` | Detailed QA evidence |

**Gap:** No concise "AI prompts used → human corrections made → outcome verified" narrative with specific examples. The artifacts exist but are distributed across multiple long documents.

---

## 10. Deployment and Demo Readiness

| Deliverable | Status | Evidence | Required Action |
|---|---|---|---|
| Deployed frontend (public URL) | **FAIL** | No URL anywhere | Deploy and add URL to README |
| Deployed Rails API | **FAIL** | No URL; no Dockerfile/Procfile/cloud config | Deploy and document |
| Hosted PostgreSQL | **FAIL** | Neon selected (DR-20) but not provisioned | Provision and migrate |
| Production CORS config | **PARTIAL** | `cors.rb` reads `CORS_ALLOWED_ORIGINS`; env not set | Set to deployed frontend origin |
| Production SSL enforcement | **PARTIAL** | `config.force_ssl` commented out in `production.rb` | Uncomment or rely on host-level HTTPS |
| Write-key management in production | **PARTIAL** | Mechanism exists; key not provisioned | Set `DEMO_WRITE_KEY` env on host |
| `btree_gist` on Neon | **UNVERIFIED** | Extension not confirmed available on Neon Free | Test `CREATE EXTENSION btree_gist` before migration |
| Database migration on hosted DB | **FAIL** | No hosted DB exists | Run after provisioning |
| Seed on hosted DB | **FAIL** | No hosted DB exists | Run with `ALLOW_PRODUCTION_SEED=1` |
| Demo video | **FAIL** | Zero video files; zero video links in repo | Record and add link to README |
| Repository publicly accessible | **UNVERIFIED** | Remote URL exists; visibility not verified | Confirm repo is public or assessor has access |
| Reply to assessment email | **NOT DONE** | Explicitly not performed in this audit | Owner must reply with repository link |

---

## 11. Gap Register

| ID | Severity | Requirement affected | Observed behavior | Expected behavior | Evidence | User impact | Recommended fix |
|---|---|---|---|---|---|---|---|
| G-01 | **P0** | R-07 — Deployed software | No hosted application exists | Live URL accessible to assessors | No deployment config file found; README confirms "No hosted CI or deployment is configured" | Assessors cannot evaluate the running application | Deploy frontend + Rails API + PostgreSQL; document URLs in README |
| G-02 | **P0** | R-08 — Video demonstration | No video file or link anywhere | A video demonstrating key workflows | File search: zero video files; README: no video link | Assessors cannot see a demo | Record video covering directory, profile, revision, analytics, CSV; add accessible link to README |
| G-03 | **P0** | Submission — Git cleanliness | `backend/db/schema.rb` is modified but not committed | Working tree clean before submission | `git status --short` shows ` M backend/db/schema.rb` | Reviewer sees inconsistency; repo not in clean submittable state | `git add backend/db/schema.rb && git commit -m "chore: sync schema.rb"` |
| G-04 | **P1** | R-07 — Production security | `config.force_ssl` commented out in `production.rb` | SSL enforced at Rails level for a write endpoint | `production.rb` inspection | Write key transmitted without TLS if hosting provider does not enforce HTTPS | Uncomment `config.force_ssl = true` or `config.assume_ssl = true` based on host |
| G-05 | **P1** | R-07 — `btree_gist` compatibility | Extension verified only on local PostgreSQL 14.25 | Schema migration succeeds on hosted database | DR-20 explicitly open; copilot-instructions.md warns of this | Deployment migration may fail; entire application cannot start | Test `CREATE EXTENSION btree_gist` on Neon before running `db:migrate` |
| G-06 | **P2** | R-09 — AI artifacts | AI use documented at high level only | Specific prompt examples and corrections documented | Multiple docs describe AI involvement generally; no linked session examples | Assessors may not appreciate intentionality | Add concise AI narrative (what was delegated, what was corrected, what was verified) |
| G-07 | **P2** | R-01 — Git history | 5 commits all on a single day | "Meaningful incremental development history" | `git log --oneline` output | Reviewer may interpret as a single-session implementation | Explain in README that requirements → architecture → backend → frontend → fixes sequence reflects the development approach; do NOT fabricate commits |
| G-08 | **P2** | Code quality | `frontend/dist/` (build output) tracked in Git | Build artifacts not committed | Repo structure shows `frontend/dist/` directory | Repo contains unnecessary generated binary content | Add `frontend/dist/` to `.gitignore`; `git rm -r --cached frontend/dist/` |
| G-09 | **P2** | Testing — coverage | No dedicated spec for `ReferenceDataQuery` | Unit test coverage for the reference data query | Spec file search | Missing coverage for `has_rate` currency logic | Add spec covering currency `has_rate` logic, ordering, empty states |
| G-10 | **P3** | Analytics — efficiency | `status_counts` runs a separate query outside the main CTE | Could be folded into a single SQL query | `summary.rb` line 113 | Minor: one extra DB round-trip per analytics request | Optional: incorporate status counts into main group_stats CTE |

---

## 12. Required Actions Before Submission

The following actions must be completed **in order**. Each is mandatory.

### Action 1 — Commit `schema.rb` *(P0 — do first)*

**What:** Stage and commit the modified `backend/db/schema.rb` file.  
**Why:** The working tree is dirty. The submitted repository must have a clean `git status`.  
**Verify:** `git status --short` shows no modified tracked files.

### Action 2 — Remove `frontend/dist/` from tracking *(P2 — do before final commit)*

**What:** `echo 'dist/' >> frontend/.gitignore && git rm -r --cached frontend/dist/ && git commit -m "chore: untrack build artifacts"`  
**Why:** Build artifacts should not be in source control.  
**Verify:** `git ls-files frontend/dist` returns empty.

### Action 3 — Fix production SSL config *(P1 — before deploy)*

**What:** In `backend/config/environments/production.rb`, uncomment `config.assume_ssl = true` (if behind a TLS-terminating reverse proxy, which Render/Railway/Fly all are) or `config.force_ssl = true`.  
**Why:** Write key must travel over TLS.  
**Verify:** Production Rails server refuses HTTP; HTTPS works.

### Action 4 — Verify `btree_gist` on Neon *(P1 — before deploy)*

**What:** Connect to Neon Free plan database; run `CREATE EXTENSION IF NOT EXISTS btree_gist;`  
**Why:** If this fails, the entire schema migration will fail and the application cannot start.  
**Verify:** Extension appears in `\dx` output with no error.

### Action 5 — Provision and deploy backend *(P0)*

**What:** Choose a hosting provider; provision PostgreSQL with `btree_gist`; deploy Rails API with `RAILS_ENV=production`, `SECRET_KEY_BASE`, `DATABASE_URL`, `CORS_ALLOWED_ORIGINS=<frontend-URL>`, `DEMO_WRITE_KEY`.  
**Why:** R-07 (deployed software) is a mandatory assessment deliverable.  
**Verify:** `GET <host>/up` returns 200; `GET <host>/api/v1/employees` returns JSON.

### Action 6 — Run migrations and seed on hosted database *(P0)*

**What:** `bin/rails db:migrate; ALLOW_PRODUCTION_SEED=1 bin/rails db:seed`  
**Why:** Hosted database must contain the 10,000 synthetic employees.  
**Verify:** `GET <host>/api/v1/analytics/summary` returns `active_headcount: 9200` and `total_annual_base_reporting: "586288203.19"`.

### Action 7 — Deploy frontend *(P0)*

**What:** `npm run build` with `VITE_API_BASE_URL=<deployed-Rails-URL>`; deploy `dist/` to a static host (Vercel, Netlify, Render static site, etc.).  
**Why:** R-07 requires a functional end-to-end application.  
**Verify:** Opening the hosted frontend URL shows the employee directory; salary revision works with the demo write key; analytics shows live data.

### Action 8 — Record demo video *(P0)*

**What:** Record a screen capture of the **deployed** application demonstrating: search/filter employees, view employee profile + salary history, submit a salary revision (showing success path), view the compensation analytics dashboard, download a CSV export.  
**Why:** R-08 (video demonstration) is a mandatory assessment deliverable. The PDF specifies no required duration or format.  
**Verify:** Video is accessible via public link (Loom, YouTube, Google Drive, etc.); link added to README.

### Action 9 — Update README and reply to assessment email *(P0)*

**What:** Add a "Live demo" section to README.md with hosted frontend URL, hosted API URL, and demo video link. Then reply to the original assessment email with the GitHub repository link.  
**Why:** Assessors need direct access to the deployed application and video; the assessment requires replying to the email.  
**Verify:** README contains clickable links; email sent.

---

## 13. Final Assessment Verdict

### FUNCTIONALLY COMPLETE — SUBMISSION REQUIREMENTS PENDING

The ACME Salary Management application is **functionally complete** and **locally verified** to a high standard:

- Rails 8.1 API with correct financial calculations (BigDecimal, no float, per-row rounding confirmed at $586,288,203.19)
- PostgreSQL schema with EXCLUSION constraint, partial unique index, and 7 CHECK constraint groups
- Two-connection real concurrency test validates serialization under PG row-level locking
- 10,000 synthetic employees verified with zero data-integrity violations (overlaps, gaps, FX mismatches)
- React 19 SPA with server-side pagination, URL-backed state, write-key memory-only security
- 358 backend + 55 frontend tests (documented prior runs); genuine test database safety guard
- All five product workflows function correctly on the local stack

**The application cannot be submitted because three P0 blockers exist:**

1. **No deployed application** — the most visible mandatory deliverable is entirely absent
2. **No demo video** — the second mandatory submission deliverable is entirely absent  
3. **Working tree is dirty** — `schema.rb` modified but not committed

None of the three blocking items require new feature development. They are operational tasks (commit, deploy, record, email). The functional foundation is solid enough to support immediate deployment work.

**Once Actions 1–9 are complete, the project is ready to submit.**

---

*Report produced 17 November 2026. No application code was modified, no database was altered, no commits were made, and no deployment was performed during this audit. All DB queries were read-only against `backend_development`. The PDF assessment document was not independently read from the workspace file tree; requirements were evaluated from the reproduction in the audit prompt.*
