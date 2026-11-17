# Implementation Plan

**Precedence:** rank 6 in the hierarchy defined in `architecture-review.md` §1. It sequences work; it does not define business rules or API behaviour.
**Status:** Phase 2 has a historical verification record (17 November 2026). Pre-existing backend work spanning Phases 3–7 is present and preserved, but its existence does not establish acceptance or authorize further implementation (see `audit-report.md`). Further Phase 3 and later work is blocked: gate G1 has not passed (remaining: `btree_gist` has not been verified on the hosted database, DR-20, and the owner has not yet signed off the delegated decisions). No estimates, durations or performance targets appear here: the assessment specifies none and nothing has been measured.

Decisions are tracked **only** in the register (`architecture-review.md` §3). Each phase below lists the decisions it is blocked by; a phase must not begin while any blocking decision is still `[APPROVAL]`. Approved decisions stay in the "Blocked by" lists for traceability; a phase is blocked only by the ones still open. The "Blocked by" lists follow the "Blocks" lines of the register and are cumulative with earlier gates (G1 → G2 → G3 …); where they differ, the register wins and this plan must be corrected.

General rules for every phase: follow `.github/copilot-instructions.md`; check the register before implementing; small incremental commits; do not commit or push without explicit owner permission; do not claim a check passed unless it was run; stop and ask when a blocking decision is open.

## Approval gates

| Gate | Blocks | Decisions that must be approved |
|------|--------|---------------------------------|
| **G0** | Phase 2 | Owner's explicit approval of the six documents and the register; DR-24 (baseline dependencies) |
| **G1** | Phase 3 | DR-01, DR-03, DR-05, DR-09, DR-11, DR-12, DR-14, DR-20 (database provider chosen and `btree_gist` verified, or weaker fallback explicitly approved), DR-21 (decided from the Phase 2 spike) |
| **G2** | Phase 4 | DR-04, DR-06, DR-07, DR-10 (and G1) |
| **G3** | Phase 5 | DR-02, DR-18, DR-19, DR-23 (write-endpoint rate-limiting decision) (and G2) |
| **G4** | Phases 6, 7 | Phase 6: DR-17 (and DR-07 from G2). Phase 7: DR-08, DR-13, DR-15, DR-16 |
| **G5** | Phase 11 | DR-22 (hosting, topology and CORS handling, including production configuration of the existing `rack-cors`) |

Gate status (17 November 2026; details in `architecture-review.md` §3.1). Nothing in this repository is evidence of owner approval; a gate is passed only when the owner explicitly approves its decisions and the register is updated.

| Gate | Status |
|------|--------|
| G0 | DR-24 approved; Phase 2 complete. Owner approval of the six documents as a whole is not recorded as a separate act (requested in the register, §11) |
| **G1** | **Not passed.** Decided: DR-01, DR-03, DR-11, DR-21 (owner); DR-05, DR-09, DR-12, DR-14 (delegated, owner review pending); DR-20 provider selected (Neon Free plan). **Remaining:** live `btree_gist`/exclusion-constraint check on the hosted database (`architecture-review.md` §12.5) and the owner's sign-off |
| G2 – G4 | Low-risk decisions now recorded under delegation; owner gate sign-off and G1 remain pending |
| G5 | DR-22 remains open |

### G1 checklist (Codex audit, 17 November 2026)
Status key: **PASS** supported by evidence; **FAIL** known unsatisfied; **BLOCKED** requires missing information or external action; **NOT TESTED** verification not performed. Prior approvals are recorded assertions in the existing register; Git does not independently authenticate the owner's earlier instructions. This request permits low-risk delegated decisions but does not itself supply final owner gate sign-off.

| # | G1 prerequisite | Status | Evidence / required next action |
|---|-----------------|--------|---------------------------------|
| 1 | DR-01 approved | PASS | Existing owner approval record; UTC microsecond timestamps, increasing same-day revisions |
| 2 | DR-03 approved | PASS | Existing owner approval record; active-only totals, on_leave revisable |
| 3 | DR-05 decided | PASS | Existing delegated FX snapshot decision preserved; owner sign-off tracked in row 12 |
| 4 | DR-09 decided | PASS | Existing delegated last-salary-held decision preserved; row 12 |
| 5 | DR-11 approved | PASS | Existing owner approval record; entered amount maximum 1000000000.00 |
| 6 | DR-12 decided | PASS | Existing delegated trimmed free-text reason, 1–255 chars; row 12 |
| 7 | DR-14 decided | PASS | Existing delegated currencies table/reference_data decision; row 12 |
| 8 | DR-21 approved | PASS | Existing owner approval of schema.rb, varchar codes and CHECKs |
| 9 | DR-20 design verified locally | PASS | Historical PostgreSQL 14.25 spike record (§12.1), 11 probes passed as recorded; not reproduced in this audit; does not prove 17/18 or hosted support |
| 10 | DR-20 database provider chosen | PASS | Existing Neon Free selection preserved; official docs rechecked (§12.6); direct URL, supported PG17 or 18 |
| 11 | DR-20 btree_gist and exclusion constraint verified on hosted database (or approved weaker fallback) | BLOCKED | No hosted database/role or result supplied; no resources authorized. Run §12.5 under separate authorization; no fallback approved |
| 12 | Owner explicit sign-off of delegated decisions, provider and hosted result | BLOCKED | Not recorded; owner review after row 11. Current delegation is not final sign-off |
| — | Additional readiness evidence (not additional G1 gate criteria) | | |
| 13 | Documentation consistency | PASS | Current statuses and decision references reconciled; pre-existing code discrepancy recorded, not hidden; `audit-report.md` |
| 14 | Repository scaffold readiness | BLOCKED | Frontend checks pass; backend lint/autoload/static scan pass; RSpec cannot connect to PostgreSQL in sandbox (0 examples, 22 loading errors). Re-run database suite |
| 15 | Dependency consistency | PASS | pagy/faker/lucide-react already absent; npm root declarations match lockfile; bundle check passes; no dependency changes |
| 16 | Clean setup reproducibility of current tree | NOT TESTED | Prior clean-copy claim predates backend additions; no reinstall or clean-clone run in this audit. Verify fresh current-tree setup with running PostgreSQL |
| 17 | Full hosted compatibility: migration, schema load/prepare, seed, TLS connection | NOT TESTED | Documentary feasibility only; execute on disposable hosted database with intended role after authorization |
| 18 | Deployment readiness | BLOCKED | DR-22 application host/topology/CORS open; no deployment config or smoke test. G5/Phase 11 responsibility |
| 19 | Whole-document G0 approval and tooling interpretation | BLOCKED | Separate owner approval not recorded; existing Phase 2 work is historical evidence, not retroactive approval. Include in owner review |

**G1 remains OPEN.** Rows 11 and 12 must pass; earlier G0 sign-off must also be recorded before implementation is resumed. Readiness rows 13–19 do not silently expand or relax the original G1 definition.

Every blocker in the register appears in a gate: DR-01 (G1), DR-02 (G3), DR-03 (G1), DR-04 (G2). Phase 1 ends only when G0 is passed **and** the G1 items are either approved or explicitly scheduled for resolution during Phase 2 (DR-20 verification and DR-21 spike) before Phase 3 starts.

## Dependency overview and critical path

```mermaid
flowchart LR
    P1[1 Planning and approval] --> P2[2 Bootstrap]
    P2 --> P3[3 Schema and models]
    P3 --> P4[4 Calculations and revision service]
    P4 --> P5[5 Employee APIs and CSV]
    P3 --> P6[6 Seed]
    P4 -.->|rate and calculation rules| P6
    P5 --> P7[7 Analytics]
    P6 --> P7
    P2 --> P8[8 React structure]
    P5 --> P8
    P8 --> P9[9 UI]
    P7 --> P9
    P9 --> P10[10 Integration and performance]
    P10 --> P11[11 Deployment]
    P11 --> P12[12 README video submission]
```

**Critical path:** 1 → 2 → 3 → 4 → 5 → 7 → 9 → 10 → 11 → 12.
**Parallelisable:** Phase 6 (seed) alongside Phases 4–5 once Phase 3 is done; the Phase 8 skeleton can start after Phase 2 against the approved contract with fixtures (the live-API integration in Phase 8 needs Phase 5); README drafting and AI-artifact collection run throughout.

## Endpoint coverage

| Endpoint (`api-contracts.md`) | Built in | UI in |
|-------------------------------|----------|-------|
| `GET /employees` | Phase 5 | Phase 9 directory |
| `GET /employees/:id` | Phase 5 | Phase 9 detail |
| `POST /employees/:id/salary_revisions` | Phase 5 (service: Phase 4) | Phase 9 revision form |
| `GET /analytics/summary` | Phase 7 | Phase 9 dashboard |
| `GET /employees/export.csv` | Phase 5 | Phase 9 export link |
| `GET /reference_data` (DR-14) | Phase 5 | Phases 8–9 filters/forms |
| Framework health route (outside the contract) | Phase 2 | — |

---

## Phase 1 — Planning and architecture approval (in progress; G1 items open)

- **Goal:** an agreed, internally consistent design with every blocking decision resolved or explicitly scheduled.
- **Scope:** owner review of the six documents; resolve `[APPROVAL]` items in the register by gate; apply approved decisions to the documents; update the register statuses.
- **Prerequisites:** `docs/requirements.md`; the owner-held assessment source.
- **Deliverables:** `.github/copilot-instructions.md`, `docs/architecture.md`, `docs/domain-decisions.md`, `docs/api-contracts.md`, `docs/implementation-plan.md`, `docs/architecture-review.md`.
- **Acceptance:** gate G0 passed; G1 items approved or scheduled; no document describes a pending decision as approved.
- **Checks:** read-through for cross-document contradictions; Mermaid diagrams render; the consistency audit in `architecture-review.md` is repeated after owner changes.
- **Commit:** `docs: add architecture, domain decisions, API contracts and Copilot guidance` (only when the owner asks for a commit).
- **Resolves (does not wait on another phase):** gate G0 — DR-24 and the owner's explicit approval; the G1 items are approved here or scheduled per the note under the gate table.

## Phase 2 — Repository and application bootstrap (completed and verified, 17 November 2026)

- **Goal:** empty-but-running Rails API and React app in one monorepo, plus a database capability spike.
- **Scope:** `.gitignore` (including `.DS_Store`); Rails API-only app in `backend/` (PostgreSQL, RSpec); Vite React-TS app in `frontend/` (Tailwind, Vitest + RTL, TanStack Query, router — exactly the DR-24 list); the framework health route; one trivial passing test per side; README stub with pinned versions chosen from what is current at that time. **Capability spike (not committed as product code):** on a throwaway local database, confirm (a) `btree_gist` can be enabled, (b) an exclusion constraint on a `tstzrange` plus CHECKs and a partial unique index are dumped and reloaded faithfully by the pinned Rails version, to settle DR-21. The owner verifies the chosen hosted PostgreSQL supports `btree_gist` (DR-20).
- **Prerequisites:** gate G0; local PostgreSQL.
- **Deliverables:** `backend/`, `frontend/`, `.gitignore`, README stub, lockfiles; a short written spike result recorded in the register (DR-20, DR-21).
- **Acceptance:** `rails server` boots; both test suites pass; SPA reaches the health route in development; no dependency outside DR-24; DR-20/DR-21 outcomes recorded.
- **Checks:** run both suites and report real output; list dependencies against DR-24.
- **Commits:** `chore: bootstrap Rails API`, `chore: bootstrap React app`, `docs: pin versions in README`.
- **Blocked by:** DR-24 (gate G0).
- **Risks:** version compatibility; schema dump fidelity; hosted database lacks `btree_gist` (then the owner chooses another provider or approves the weaker fallback **before** Phase 3).
- **Historical result (recorded before this audit):** the scaffold exists in `backend/` (Rails 8.1.4.1 API-only, PostgreSQL, RSpec; health route `GET /up`; the contract's 400/404/500 error shape; CORS for configured origins; 9 specs) and `frontend/` (React 19, TypeScript strict, Vite, React Router, TanStack Query, Tailwind 4, Vitest + RTL; app shell and temporary health status page; 5 tests), plus root `README.md`, `Makefile`, `.editorconfig`, `.gitignore` and `.env.example` files. Commands run: `make check` — `bin/ci` (RuboCop clean, bundler-audit no vulnerabilities, Brakeman 0 warnings, RSpec 9 examples / 0 failures) and the frontend typecheck, ESLint, Vitest (5 tests passed) and production build. A live check showed `GET /up` → 200, the Vite origin allowed by CORS and a foreign origin refused, and an unknown route returning the contract's 404 body.
- **Dependencies:** aligned with DR-24 on 17 November 2026 (`pagy`, `faker`, `lucide-react` removed; Tailwind 4 approved; `rack-cors` for local development only).
- **Capability spike:** run in an isolated temporary copy; the record is `architecture-review.md` §12. DR-21 is decided (`schema.rb`). The hosted-provider verification for DR-20 is **not** done.
- **Historical Phase 2 boundary:** the scaffold at that time had no business model, migration, schema or seed. The audit now finds pre-existing backend feature work; its approval/completion is not established. No feature UI is present.

## Phase 3 — Database schema, models, constraints, model specs

- **Goal:** the six tables with all constraints; models with validations.
- **Scope:** `btree_gist`; migrations for `countries`, `departments`, `currencies` (DR-14), `employees`, `salary_records` (CHECKs, partial unique index, exclusion constraint), `exchange_rates`; country and currency codes as `varchar(2)`/`varchar(3)` with explicit length and uppercase-format CHECKs (DR-21); models, enums, associations; read-only discipline for past salary records; `db/schema.rb` (DR-21). `salary_records` carries `fx_rate` (DR-05) and `reason varchar(255)` with a non-blank CHECK (DR-12); `employees` carries the `terminated_on` CHECK (DR-09). Explicit names for every constraint and index. Phase 3 verification runs on the same PostgreSQL major as the hosted database (17 or 18, not the end-of-life 14 installed today).
- **Prerequisites:** gate G1.
- **Deliverables:** migrations, schema file, models, minimal factories, model specs.
- **Acceptance:** the database rejects two open records, overlapping closed ranges, `effective_to <= effective_from`, non-positive amount/rate, bad status/frequency, `terminated_on` mismatch, unknown currency; boundary-touching `[a,b)` + `[b,c)` is accepted.
- **Checks:** specs against the real database for each constraint (no mocks); a spec showing the **partial unique index alone does not block a historical overlap** while the exclusion constraint does; the schema file reloads into an empty database: verify `db:schema:load` and `db:prepare` on a fresh database, and that the `varchar` + regex CHECKs survive the `schema.rb` round trip (the spike used `char(n)`, so this variant is verified here).
- **Commits:** `feat(db): add schema with salary interval constraints`, `test: model and constraint specs`.
- **Blocked by:** gate G1 — remaining items: the hosted `btree_gist` verification (DR-20, procedure in `architecture-review.md` §12.5) and the owner's sign-off of DR-05, DR-09, DR-12 and DR-14 (decided under delegated authority). DR-01, DR-03, DR-11, DR-21 and the design of DR-20 are approved. Phase 3 does not start until the gate passes.

## Phase 4 — Salary calculations and revision service

- **Goal:** money rules and the revision workflow, fully tested, no HTTP.
- **Scope:** annualization, conversion and rounding in Ruby (`BigDecimal`) and the one SQL fragment; amount parsing per `domain-decisions.md` §4.3; rate lookup per §3.3; `SalaryRevisions::Create` implementing `domain-decisions.md` §7 in its exact order: lock employee → read current record after the lock → token check (DR-04) → eligibility → validate request data and no-op → **one** clock read, truncated once → FX lookup by that timestamp's UTC date → reject if not later than the current `effective_from` → close previous → insert new → commit; injectable clock.
- **Prerequisites:** gate G2.
- **Deliverables:** calculation module, SQL fragment module, parser/validator, service, specs.
- **Acceptance:** worked examples in `domain-decisions.md` §4.2 pass exactly; **SQL and Ruby agree on a shared fixture set (parity tests)**; previous `effective_to` equals new `effective_from` exactly (no offset); the rate lookup date is the UTC date of the same timestamp; a clock double that raises on a second call proves a single read; a spec proves the current record is read only after the lock; every error path writes nothing; one spec per condition: stale token (`stale_salary_record`), each employment status (`active`/`on_leave` succeed, `terminated` → `employee_not_eligible`, subject to DR-03), `no_change`, `missing_exchange_rate`, `revision_conflict`, and invalid-amount cases (valid/invalid syntax table, scientific notation, >2 decimals, zero, over bound, over capacity); JSON-number amounts are rejected at the controller layer (Phase 5).
- **Checks:** concurrency spec with two connections revising the same employee: one succeeds, the other gets a stale-token or serialized result, history stays valid (transactional tests off for that spec; deterministic, not time-based).
- **Commits:** `feat: salary calculations`, `feat: salary revision service`.
- **Blocked by:** DR-01, DR-03, DR-04, DR-05, DR-06, DR-07, DR-09, DR-10, DR-11, DR-12.
- **Risks:** SQL/Ruby formula drift; microsecond truncation; transactional-test interaction with locks.

## Phase 5 — Employee APIs, pagination, filters, CSV export

- **Goal:** implement the **exact** approved contracts for endpoints 1, 2, 3, 5 and 6 of `api-contracts.md`.
- **Scope:** routes (export before `:id`); `Employees::Directory` (shared by list and export; offset pagination implemented directly, no pagination gem); serializers; error mapping for every code in the contract table; write-key check per `architecture.md` §9.3 (`403` before `401`, constant-time compare, fail closed, never log the header); CSV streaming; reference data with the `has_rate` definition.
- **Prerequisites:** gate G3 (read endpoints may start after Phase 3).
- **Deliverables:** controllers, query object, serializers, request specs.
- **Acceptance:** every response matches the contract examples; strict parameter validation; stable pagination; `page` malformed/zero/negative → 400, page beyond last → 200 with empty `data`, empty result → `total_pages: 0`; export applies the same filters **and sort/direction** as the directory, ignores paging and includes all matching rows; list and export share the filter code; money is always strings; JSON-number `amount` → 400; each error code in the contract table reachable and tested in the documented precedence order (including `403` before `401` when no key is configured, and `internal_error` returning a generic body with no exception text); history returned newest first.
- **Checks:** request specs per status code; query-count specs for list and detail (no N+1); **CSV spec covering every case in the sanitization table of `api-contracts.md` §5** (direct `= + - @`, whitespace-preceded, leading TAB/CR/LF, embedded commas/quotes/newlines, ordinary negative numeric values left intact, text `-100.00` prefixed) plus empty result and sort order; SQL-injection attempts in `q` and `sort`; spec that the write key never appears in logs or responses.
- **Commits:** `feat(api): employee directory`, `feat(api): employee detail`, `feat(api): salary revision endpoint`, `feat(api): CSV export`, `feat(api): reference data`.
- **Blocked by:** DR-01, DR-02, DR-03, DR-04, DR-05, DR-11, DR-14, DR-18, DR-19, DR-23. (The reference-data `low_sample_threshold` field waits for DR-08 and is added in Phase 7.)

## Phase 6 — Deterministic 10,000-employee seed

- **Goal:** repeatable synthetic dataset exactly as specified.
- **Scope:** `Seeds::DemoDataset` with fixed RNG seed and anchor date; curated name lists; reference data, rates, employees, historical + open salary records via batched bulk insert; production guard; post-seed verification; a small-N mode for tests.
- **Prerequisites:** Phase 3, gate G1, DR-07 (from G2) and gate G4 (DR-17). Phase 6 does not need Phases 4–5 but must reuse the rate-lookup and calculation rules (Phase 4 deliverables) for seeded `fx_rate` and verification, so verification that needs them runs after Phase 4.
- **Deliverables:** seed code, data files, specs, documented command.
- **Acceptance:** exactly 10,000 employees; every employee has exactly one open record; no overlaps; `terminated_on` rules; every record has `fx_rate`; coverage per `domain-decisions.md` §11 including a below-threshold group and countries sharing a currency; `status_counts` sum to 10,000; two consecutive runs produce identical data fingerprints.
- **Checks:** run the seed, run the verification queries, compare a stable fingerprint across two runs. Report runtime only as a measured fact.
- **Commit:** `feat: deterministic demo seed`.
- **Blocked by:** DR-03, DR-05, DR-07, DR-17.
- **Risks:** bulk insert bypasses model validations (DB constraints and verification cover the gap); realism creep.

## Phase 7 — Compensation analytics and query tests

- **Goal:** endpoint 4 using **exact numeric analytics**.
- **Scope:** `Analytics::Summary`: totals/average over rounded per-employee values; **exact numeric median** via `ROW_NUMBER()` ranking and group counts (`domain-decisions.md` §10.3) with no `percentile_cont` and no `double precision` cast; filters; `low_sample`; `local_totals`; `status_counts` semantics; empty-group contract; add `low_sample_threshold` to reference data once DR-08 is approved.
- **Prerequisites:** Phases 5 and 6 (or fixtures); gate G4.
- **Deliverables:** query object, controller, serializer, specs.
- **Acceptance:** active-only metrics; no raw cross-currency sums; totals equal the sum of rounded employee rows; median specs for odd, even, even-with-half-cent, even-with-duplicates, single-row, large-magnitude and empty cases at organization, country and department level; `status_counts` sums to 10,000 unfiltered and to the filtered population when filtered; empty result returns `"0.00"`/`null` and omits empty groups; no `NaN`.
- **Checks:** hand-computed small fixtures (mixed currency/frequency); dashboard total equals the CSV `annual_base_usd` sum for `status=active`; a spec that fails if the median uses `percentile_cont` or a float cast; a check on the pinned PostgreSQL version of the coercion behaviour described in `domain-decisions.md` §10.3.
- **Commit:** `feat(api): compensation analytics`.
- **Blocked by:** DR-03, DR-06, DR-08, DR-13, DR-15, DR-16.

## Phase 8 — React application structure and API integration

- **Goal:** typed API layer on top of the SPA shell that Phase 2 already delivered (router, layout, query client, `lib/api.ts`, health status page); no feature UI.
- **Scope:** routes, layout, API client with error mapping for every contract code, TanStack Query hooks, types mirroring the contracts, a money **display-only** formatter, in-memory write-passphrase state (React state only; lost on page reload or tab close, **not** cleared by client-side route changes, discarded on `401`; never in `localStorage`/`sessionStorage`/cookies/URLs/`VITE_*`).
- **Prerequisites:** Phase 2; the approved contract (fixtures allowed before the backend is ready; live integration after Phase 5); DR-22 should be known because it fixes the API base URL and CORS needs.
- **Deliverables:** `frontend/src` structure, client/formatter tests.
- **Acceptance:** hooks fetch from a running backend; typed errors surface; **no money arithmetic, comparison or aggregation in TypeScript** (money values stay strings; only formatting); passphrase handling as specified.
- **Checks:** `vitest run`, type-check, lint if configured; a test that amounts remain strings end-to-end.
- **Commit:** `feat(ui): app shell and API client`.
- **Blocked by:** DR-02, DR-14, DR-18. (DR-22 should be known before this phase because it fixes the API base URL and CORS needs, but is a hard gate only at Phase 11.)

## Phase 9 — Dashboard, directory, employee detail and revision UI

- **Goal:** the four user workflows matching the approved API and eligibility rules.
- **Scope:** directory (search/filters/sort/pagination in URL; export link carries filters, **sort and direction**, not paging); detail with history (newest first); revision form with eligibility from `can_revise_salary` (DR-03, approved: `on_leave` allowed, `terminated` not) and handling of **401, 403, 409 (`stale_salary_record` and `revision_conflict`), 422 (`employee_not_eligible`, `validation_failed`, `no_change`, `missing_exchange_rate`)** as in `architecture.md` §9.3, plus generic 400/500; cache invalidation after success; dashboard showing group sizes, low-sample flag, empty-state, caveat copy.
- **Prerequisites:** Phases 7 and 8.
- **Deliverables:** components, pages, tests.
- **Acceptance:** each workflow works end-to-end in a browser; low-sample groups visibly flagged; caveat text present; terminated employees show no revise action while on-leave employees do; no wording implying pay inequity, attrition or compa-ratio; export-button note on reconciliation with the dashboard.
- **Checks:** RTL tests for filters→URL→request, export link params, revision errors per code, passphrase clearing on 401, hidden form on 403, stale-token reload; a real manual browser pass.
- **Commits:** one per page/workflow.
- **Blocked by:** DR-01, DR-02, DR-03, DR-04, DR-08, DR-14, DR-16, DR-18.
- **Risks:** UI scope creep (charts need approval).

## Phase 10 — Integration, regression and performance verification

- **Goal:** confidence on the full 10,000-row dataset with **actual measurements**.
- **Scope:** end-to-end happy paths on the seeded database; regression pass over all invariants (`domain-decisions.md` §13); measure list, filter, search, analytics and export on 10,000 rows (`EXPLAIN ANALYZE`, timings recorded with machine and configuration); measure the detail endpoint with a long-history fixture (DR-19); add an index only if a measurement justifies it; frontend types vs contracts cross-check.
- **Prerequisites:** Phases 6–9.
- **Deliverables:** minimal integration checks; a README "performance" section containing only measured numbers; any justified index.
- **Acceptance:** all suites green; no N+1; invariants hold after exercising revisions on seeded data; every number reported is a measurement with its context, never an estimate. The assessment sets no performance target, so none is asserted.
- **Commits:** `test: integration checks`; `perf: <index>` only if measured.
- **Risks:** slow `ILIKE` search (fallback `pg_trgm` needs approval); slow exact median (optimize the query before considering any cache).

## Phase 11 — Deployment and production demo-data verification

- **Goal:** the approved design deployed and working.
- **Scope:** hosting per DR-22; database on Neon (DR-20; hosted `btree_gist` verification is still a G1 prerequisite before further Phase 3 work; no deferral is approved); environment secrets; HTTPS; CORS or same-origin; migrations and one seed run; verification.
- **Prerequisites:** Phase 10; gate G5.
- **Deliverables:** deployment configuration (first created here), runbook, production smoke checklist.
- **Acceptance:** exactly 10,000 employees in production; invariant queries pass; revision succeeds with the key and is refused with `401` without or with a wrong key; with the key unset a non-production verification instance returns `403 writes_disabled`; CSV downloads with filters and sort; CORS (if cross-origin) allows only the configured origins and never a wildcard; no secret in the repository, the built bundle or logs (including the `Authorization` header); writes only over HTTPS; `500` responses carry no internal details; throttling in place only if DR-23 approved it.
- **Checks:** run verification queries against production; inspect the bundle and logs; attempt an unauthenticated and a wrong-key `POST`; request from a non-allow-listed origin.
- **Commits:** `chore: deployment configuration`, `docs: deployment runbook`.
- **Blocked by:** DR-02, DR-22 (and DR-23 if throttling was approved).
- **Risks:** provider limits, cold starts, export timeouts, seed run limits — unknown until a provider is chosen.

## Phase 12 — README, AI artifacts, video demo and final email submission

- **Goal:** a complete submission that satisfies the **actual assessment requirements**.
- **Scope:** README (overview, run instructions, architecture diagram, trade-offs, measured performance, **documented AI-assisted work**: how AI was used, prompts and instructions); committed design/AI artifacts (`docs/`, `.github/prompts/`, `.github/copilot-instructions.md`); the one-page requirements document (`docs/requirements.md`); a screen-recorded **video demonstration** of the deployed software; confirm the **deployed** application is functional; commit all code to the Git repository with incremental history; **reply to the same email with the repository link**.
- **Prerequisites:** Phase 11.
- **Deliverables:** README, final doc touch-ups, demo video, reply email text.
- **Acceptance:** a stranger can run the project from the README; README claims match measured facts; the write passphrase is delivered privately and never committed; commit history is incremental; the assessment PDF is **not** added to a public repository unless the owner explicitly approves; items the assessment leaves unspecified (deadline, hosting provider, video duration) are not claimed.
- **Checks:** clean-clone run-through of the README; link check; confirm the email reply contains the repository link.
- **Commit:** `docs: README and submission artifacts`.

---

## Cross-cutting checks (each phase)
- Relevant test suites pass and were actually run; reported output is real.
- No dependency or infrastructure beyond what the phase lists and the register approves.
- Documents updated when a decision changes, with the register as the single place for decision status.
- Each commit builds and its tests pass; no commit or push without explicit owner permission.
