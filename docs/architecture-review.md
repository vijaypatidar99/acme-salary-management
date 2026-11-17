# Architecture Review and Decision Register

**Status:** Partially approved. Decisions tagged **`[APPROVED]`** were approved by the owner on 17 November 2026; those tagged **`[APPROVED (delegated)]`** (DR-02, DR-05–DR-10, DR-12–DR-19 and DR-23) were decided by the architect under the owner's delegated authority of the same date and await owner review; DR-20 is **`[SELECTED — hosted verification PENDING]`**. DR-22 remains `[APPROVAL]` at G5. The Phase 2 verification below is a historical record. The audit found pre-existing backend migrations, models, services, endpoints and seed code beyond the scaffold; their presence does not establish phase approval or completion (see `audit-report.md`). **The architecture is not finalized and gate G1 has not passed**: its remaining blockers are the live `btree_gist` check on the hosted database (DR-20) and the owner's sign-off (§3.1).
**Role of this document:** it records the decision register, risks, conflicts and outstanding approvals. It is **not** a source of business rules; those live in the documents ranked above it (§1).

---

## 1. Document hierarchy (single authoritative statement)

| Rank | Source | Authority over |
|------|--------|----------------|
| 1 | Original Incubyte assessment (held by the owner; summarized in §2.1) | Assessment constraints |
| 2 | `docs/requirements.md` | Product goal, scope, workflows, exclusions |
| 3 | `docs/domain-decisions.md` | Domain rules, provided they do not contradict rank 2 |
| 4 | `docs/architecture.md` | Technical architecture implementing ranks 2–3 |
| 5 | `docs/api-contracts.md` | Externally visible API behaviour, consistent with ranks 3–4 |
| 6 | `docs/implementation-plan.md` | Implementation order and acceptance criteria |
| 7 | `docs/architecture-review.md` (this file) | Decision register, risks, recommendations, outstanding approvals. **Not** a source of business rules |
| 8 | `.github/copilot-instructions.md` | Concise instructions that enforce this hierarchy |

Rules:
- If two documents disagree, the higher-ranked source wins; record the conflict (§7) and update the lower-ranked document.
- `docs/requirements.md` is never changed silently. Proposed changes are listed in §9 and wait for explicit owner approval.
- A decision marked **[APPROVAL]** in the register (§3) is **proposed, not approved**, even if another document describes the recommended default in the present tense. Implementation of anything that depends on a pending decision must not start (see the gates in §3.1 and `implementation-plan.md`).

## 2. Baseline: what is approved, and where each thing comes from

### 2.1 Assessment requirements (authoritative; owner-provided summary of the original Incubyte assessment)
The assessment asks for: employee salary management software for an organization with 10,000 employees; an HR Manager as the primary user; a backend aligned with the role applied for (**Ruby on Rails is preferred**); ReactJS or NextJS for the UI; a relational database; a seed script that creates 10,000 employees; a **one-page requirements document**; fully functional **deployed** software; a **video demonstration**; meaningful, fast, deterministic tests; good structure, readability and maintainability; incremental Git commits; supporting artifacts (requirements, architecture diagrams, design notes, **documented AI-assisted work / AI prompts**, trade-offs, performance considerations); and good engineering judgment rather than unnecessary complexity.
**Submission:** commit the code to a Git repository and reply to the same email with the repository link.

**Not specified by the assessment (genuinely unknown, not to be claimed):** deadline, hosting provider, video duration.
The assessment PDF is held by the owner and is not committed to this repository; committing it to a public repository requires explicit owner approval. The requirements above come from the owner's summary of that PDF; this review did not read the PDF itself.

### 2.2 Classification used throughout the documents

| Category | Items |
|----------|-------|
| **Assessment requirement** | Everything in §2.1 only |
| **Agreed product requirement** (`requirements.md`) | Base-pay HR web app; directory with search/filters/pagination; profile with salary; compensation overview (active headcount and annualized base-pay totals by country/department, common reporting currency, local amounts where relevant, average/median with group size); salary revision (amount, currency, monthly/annual, reason; immediate effect; history preserved; reject non-positive amounts; prevent overlapping periods); filtered CSV export; exactly 10,000 synthetic employees with multi-country/currency/department/level/status coverage and sample history; exclusions list; USD reporting currency and fixed seeded rates; monthly ×12 annualization; totals over active employees; synthetic data; demo-only access protection |
| **Technology choice** (project/owner direction; **not** assessment requirements) | Rails API mode, PostgreSQL, RSpec, React + TypeScript + Vite, Vitest + React Testing Library, TanStack Query, Tailwind CSS, one monorepo. Versions are pinned by the lockfiles and recorded in the root `README.md` |
| **MVP design decision** | Everything in the register (§3) and the design in `architecture.md` that is not above |
| **Optional enhancement** | `reference_data` endpoint, `currencies` table, analytics `job_level` filter and `local_totals`, `rack-attack`, `pg_trgm`, a chart library |

`requirements.md` lists some items under "Key assumptions to validate" (USD reporting currency, ×12 annualization, active-only totals, immediate revisions). They are agreed MVP direction and are treated as approved baseline; the *mechanisms* used to implement them are in the register where not fixed by the brief.

### 2.3 Owner-directed corrections applied in earlier reviews
These were specified explicitly by the owner and are applied as written. They are **not** in the register unless noted:
- Half-open intervals `[effective_from, effective_to)`.
- One effective timestamp per revision, obtained after the lock (the *type* of effectivity remains DR-01).
- Exact `numeric` median (no `double precision` cast).
- Money rules: Ruby `BigDecimal`, PostgreSQL `numeric`, JSON decimal strings, display-only formatting in the frontend, no raw cross-currency sums, missing rate never defaults to 1. (The per-employee *rounding policy* remains DR-06.)
- Pagination: malformed page values → 400; page beyond the last → 200 with empty `data`.
- CSV export reuses directory filters and sort, excludes paging, same tie-breaker.
- `status_counts` semantics and the empty-group contract.
- Salary history is documented as unpaginated by trade-off (DR-19).
- Decimal-string syntax rules for amounts (the upper bound itself remains DR-11).

## 3. Decision register

Every decision has the same fields. A heading tagged **`[APPROVED]`** carries a *Decision* line recording what the owner approved (and what it does not cover); **`[APPROVED (delegated)]`** marks a decision the architect made under the owner's delegated authority, which the owner still reviews; the original recommendation text is kept beneath it for history. A heading tagged **`[APPROVAL]`** is still pending: its recommended default is used in the other documents only as a clearly labelled working default. Other documents reference these IDs instead of keeping their own lists.

### 3.1 Approval gates (what must be resolved before each phase starts)

| Gate | Must be approved before | Decisions |
|------|-------------------------|-----------|
| **G0** | Phase 2 starts | Explicit owner approval of the six documents and this register; DR-24 |
| **G1** | Phase 3 starts | DR-01, DR-03, DR-05, DR-09, DR-11, DR-12, DR-14, DR-20, DR-21 |
| **G2** | Phase 4 starts | DR-04, DR-06, DR-07, DR-10 (plus G1) |
| **G3** | Phase 5 starts | DR-02, DR-18, DR-19, DR-23 (write-endpoint rate-limiting decision) |
| **G4** | Phase 6 / 7 start | DR-17 (Phase 6, with DR-07 from G2); DR-08, DR-13, DR-15, DR-16 (Phase 7) |
| **G5** | Phase 11 starts | DR-22 (hosting, topology and CORS handling) |

**Gate status as of 17 November 2026.** A gate is passed only when the owner explicitly approves its decisions and this register is updated; nothing in the repository counts as that evidence.

| Gate | Status | Detail |
|------|--------|--------|
| **G0** | DR-24 approved; Phase 2 complete | The scaffold exists and was verified (§12, `implementation-plan.md` Phase 2). Owner approval of the six documents as a whole is not recorded as a separate act; it is requested again in §11. |
| **G1** | **Not passed** | Decided: DR-01, DR-03, DR-11, DR-21 (owner); DR-05, DR-09, DR-12, DR-14 (delegated, owner review pending); DR-20 provider **selected** (Neon, Free plan) on documentary evidence. **Remaining blockers:** (1) `btree_gist` and the exclusion constraint have **not** been verified on the hosted database (procedure in §12.5; needs a throwaway Neon project, whose creation is outside this audit’s authorization); (2) the owner's explicit sign-off of the delegated decisions and of the hosted result. |
| G2 – G4 | Not passed | Remaining low-risk defaults decided under the current delegation; explicit owner gate review and preceding G1 still pending. |
| G5 | Not passed | DR-22 application host, production topology and CORS remain open. |

Phase 3 may not start while G1 is open.

DR-21 was approved on 17 November 2026 after the Phase 2 capability spike (`schema.rb`; see §12). DR-20's hosted-provider verification is still open.

### 3.2 Blockers

**DR-01 — Effective-date type** `[APPROVED]`
- **Decision (approved 17 November 2026, owner instruction):** Salary effective values are UTC `timestamptz` with microsecond precision. Intervals are half-open, `[effective_from, effective_to)`; a record is current when `effective_to IS NULL`. Several revisions on the same UTC calendar day are permitted provided their timestamps are strictly increasing. The server determines the effective timestamp (the client cannot supply one). The timestamp is normalised to microsecond precision **once** (`Time#floor(6)`) and that same value closes the old record and opens the new one. A timestamp that is not strictly later than the current record's `effective_from` is rejected (`409 revision_conflict`). Reason for timestamps over date-only: a mistaken revision can be superseded immediately without a one-revision-per-day rule or a time-zone definition, and interval arithmetic is exact (a date-typed `[d,d)` range is empty, so date semantics would force rejecting the second same-day revision). Spike evidence: §12.
- Question: are salary effective values timestamps or dates?
- Recommended default: `timestamptz`, server-set at revision time ("effective immediately"), displayed in UTC.
- Reason: a mistaken revision can be superseded immediately even though retroactive corrections are out of scope; no calendar-day/time-zone ambiguity; exact interval arithmetic.
- Trade-off: HR convention is usually a date. Dates force a one-revision-per-day rule (the second revision would produce an empty interval) and a defined time zone for "today".
- Blocks: Phase 3 (column types), 4, 5, 9.

**DR-02 — Public-demo write protection** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Use the shared server-side demo write key and the in-memory client handling already specified in architecture.md §9.3; no accounts or RBAC. This satisfies demo-only protection without expanding product scope.
- Owner note (17 November 2026): the recommendation is kept — a server-side demo write key that is never exposed through a frontend environment variable; no full authentication/RBAC. The current delegated decision above resolves the recommendation; gate sign-off remains separate.
- Question: how are salary-revision writes protected on the public demo?
- Recommended default: shared write passphrase in `Authorization: Bearer …`, kept in React in-memory state only, compared in constant time against a server secret, fail closed (403) when unset. Reads open because all data is synthetic.
- Reason: smallest real protection for the one mutating endpoint without introducing user accounts (excluded by the brief); no secret in the frontend bundle.
- Trade-off: no per-user identity or audit attribution; the passphrase is lost when the page is reloaded or the tab is closed (re-entry), but is **not** cleared by in-app route changes; brute-force resistance depends on passphrase strength and any throttling (DR-23). Alternatives (Basic auth, session login, open writes with reset, read-only) rejected in `architecture.md` §9.2.
- Blocks: Phase 5 (endpoint), 8, 9, 11.

**DR-03 — Employment statuses and the active-payroll population** `[APPROVED]`
- **Decision (approved 17 November 2026, owner instruction):** Statuses are `active`, `on_leave`, `terminated`. **Revision eligibility** and **analytics inclusion** are different questions: `on_leave` employees **may** receive salary revisions; `terminated` employees **may not** (`422 employee_not_eligible`); compensation totals and the active compensation analytics include **only** employees whose status is `active` (so an `on_leave` employee can be revised but is not in the totals). This does **not** decide DR-09 (what happens to a terminated employee's salary history), which is resolved separately below under delegated authority.
- Question: which statuses exist, which count toward active payroll totals, which may be revised?
- Recommended default: `active`, `on_leave`, `terminated`; only `active` counts toward payroll totals (literal reading of the brief); `active` and `on_leave` may be revised; `terminated` may not.
- Reason: smallest set satisfying "employment statuses" and "active employees".
- Trade-off: `on_leave` staff are normally still paid, so excluding them from totals is debatable; the simplest alternative drops `on_leave` (two statuses). The brief does not define "active".
- Blocks: Phase 3 (CHECK), 4 (eligibility), 5 (API eligibility/filters), 6, 7, 9.

**DR-04 — Mandatory `expected_current_salary_record_id`** `[APPROVED]`
- **Decision (approved 17 November 2026, owner instruction):** `expected_current_salary_record_id` is mandatory in the salary-revision request; a mismatch returns `409 stale_salary_record`. The employee row lock stays as the transaction-level protection. The token prevents a stale client from silently overwriting a more recent revision (the lock only serialises writers) and makes a double submit harmless.
- Question: must a revision request carry the id of the current record the user saw?
- Recommended default: mandatory; mismatch → `409 stale_salary_record`.
- Reason: the row lock serializes writers but does not stop a lost update by a user working from a stale page; also makes double-submit harmless.
- Trade-off: one more field for the client to carry; optional would be simpler but permits silent overwrites. If resolved as optional, a missing token skips the check (`domain-decisions.md` §7) and the `400` for a missing token disappears.
- Blocks: Phase 4, 5, 9.

### 3.3 Important domain decisions

**DR-05 — FX-rate snapshot semantics** `[APPROVED (delegated)]`
- **Decision (Approved under delegated authority (owner instruction of 17 November 2026 authorising low-risk MVP decisions supported by the requirements and technical evidence); **owner review is requested at G1 sign-off**.)** Each salary record stores the rate used as `fx_rate numeric(18,8)`, CHECK `> 0`. *Source of the rule:* `requirements.md` already requires retaining "the conversion rate used"; only the mechanism was open. `exchange_rates` is only the lookup source: the row for `currency → USD` with the greatest `effective_on` ≤ the UTC date of the revision's single effective timestamp (DR-01); none → `422 missing_exchange_rate`, never a default of 1. There is no foreign key from `salary_records` to `exchange_rates`. Direction: 1 unit of `from_currency` = `rate` units of `to_currency`; only `to_currency = 'USD'` is seeded or used. Seeded records snapshot the rate effective at their own `effective_from`. Rationale: the simplest design that satisfies the brief, reproducible if the rate table is edited, and no extra join. Accepted trade-off: with one fixed rate per currency, totals equal a single-rate calculation; if rates ever varied over time, totals would mix rate dates. Rounding of converted values is **not** decided here (DR-06, gate G2).
- Question: how is "the conversion rate used" retained?
- Recommended default: copy the rate value onto each salary record (`fx_rate`); `exchange_rates` is only the lookup source. Rate lookup = row with the greatest `effective_on` ≤ the UTC date of the revision's effective timestamp.
- Reason: reproducible and independent of later edits to the rate table; no extra join.
- Trade-off: denormalized snapshot; totals use each record's own rate, so if rates ever varied over time, org totals would mix rate dates (harmless with one fixed rate per currency). Alternative: FK to an immutable rate row.
- Blocks: Phase 3, 4 (lookup and snapshot), 5 (responses/CSV), 6 (seeded snapshots).

**DR-06 — Per-employee rounding policy** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Adopt annualize → convert once → round once per employee to 2 dp, half away from zero; aggregate those rounded values and round averages/medians only at output. The worked examples in domain-decisions.md §4.2 establish reconciliation with visible CSV rows.
- Question: where is rounding applied?
- Recommended default: annualize → convert once → round once per employee to 2 dp (half away from zero); totals/averages/medians aggregate the rounded values; averages and medians rounded at output.
- Reason: dashboard totals reconcile exactly to the CSV rows.
- Trade-off: slightly less precise than aggregating unrounded values and rounding last.
- Blocks: Phase 4, 7.

**DR-07 — Currency independent of employee country** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Salary currency is independent of country; validate currency membership and rate availability, not a country/currency pairing. This preserves the existing multi-country/currency model without adding a business restriction.
- Recommended default: salary currency is chosen per record; not derived from or validated against country.
- Reason: the brief treats multiple currencies and countries as separate; supports expatriates/contractors and shared currencies (EUR).
- Trade-off: data-entry mismatches (e.g. an Indian employee paid in USD) are accepted silently.
- Blocks: Phase 4, 6.

**DR-08 — Low-sample threshold** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Set the named low-sample threshold to 10 active employees; expose it through reference_data. This is a display caution for small groups, not statistical significance or suppression of salary data.
- Owner note (17 November 2026): the recommendation of 10 is kept, now decided under the current delegation above; owner gate review remains pending.
- Recommended default: a group is `low_sample` when active headcount < 10 (named constant).
- Reason: the brief requires group size to be visible so small samples aren't misleading, but gives no number.
- Trade-off: arbitrary; too high flags many legitimate groups, too low misleads.
- Blocks: Phase 7 (including the `low_sample_threshold` field added to reference data) and Phase 9 (UI flag).

**DR-09 — Terminated employees and salary history** `[APPROVED (delegated)]`
- **Decision (Approved under delegated authority (owner instruction of 17 November 2026 authorising low-risk MVP decisions supported by the requirements and technical evidence); **owner review is requested at G1 sign-off**.)** A terminated employee's last salary record stays **open** ("last salary held"), so every employee has exactly one open record. Terminated employees are excluded from compensation totals and cannot be revised (both already DR-03). `terminated_on` is non-null if and only if status is `terminated`, and `terminated_on >= hired_on` (database CHECK). The MVP has no termination workflow and no status-change endpoint: status is set by the seed (`requirements.md` excludes full employee-lifecycle management). Rationale: the only option that keeps the one-open-record invariant without a lifecycle feature. Accepted trade-off: the open record means "last salary held", not "currently paid"; the UI and API do not describe it as current pay for a terminated employee.
- Recommended default: a terminated employee's last salary record stays open; they are excluded from totals; further revisions are rejected; `terminated_on` is set iff status is `terminated`.
- Reason: preserves "exactly one open record per employee"; needs no termination workflow (lifecycle management is excluded).
- Trade-off: the open record means "last salary held", not "currently paid". Alternative (close at `terminated_on`) leaves employees without a current salary.
- Blocks: Phase 3, 4.

**DR-10 — No-op salary revisions** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Reject revisions with unchanged amount, currency and frequency as 422 no_change, including reason-only submissions. The MVP records pay changes and has no review-without-change workflow.
- Recommended default: reject when amount, currency and frequency equal the current record (`422 no_change`).
- Reason: a reason-only change is not a salary revision; avoids noise in history.
- Trade-off: HR cannot log "reviewed, no change".
- Blocks: Phase 4.

**DR-11 — Salary amount upper bound** `[APPROVED]`
- **Decision (approved 17 November 2026, owner instruction):** The maximum accepted entered amount is `1000000000.00`, expressed in the salary's own currency and pay frequency. It is a per-record input limit, **not** a USD-converted limit. It is validated in the application before any write; the database's `numeric(14,2)` capacity and `amount > 0` CHECK are the second layer (there is no separate upper-bound CHECK, so the guard can change without a migration). More than two decimal places, zero and negative values are rejected before persistence, because PostgreSQL `numeric(14,2)` silently rounds extra digits (§12). No binary floating point is used for money. Trade-off accepted: the same nominal limit applies to every currency and to monthly and annual amounts.
- Question: what is the exact maximum accepted `amount`?
- Recommended default for discussion: 1,000,000,000.00 in local-currency units per pay period, as a sanity guard rather than business policy.
- Reason: rejects typos; well inside `numeric(14,2)` capacity (999,999,999,999.99).
- Trade-off: a uniform number is crude across currencies with very different scales. The bound is now approved as recorded above; the original recommendation is retained for history. Independent of the bound, values exceeding column capacity are rejected with `422 validation_failed` before reaching the database.
- Blocks: Phase 3 (if a CHECK is used), 4, 5.

**DR-12 — Revision reason** `[APPROVED (delegated)]`
- **Decision (Approved under delegated authority (owner instruction of 17 November 2026 authorising low-risk MVP decisions supported by the requirements and technical evidence); **owner review is requested at G1 sign-off**.)** `reason` is required on every salary record (including the first and seeded ones): free text, trimmed by the application before saving, 1–255 characters, not blank. Database: `NOT NULL`, `varchar(255)`, CHECK `btrim(reason) <> ''`. No controlled vocabulary or reason table. *Source:* `requirements.md` requires a reason on a revision and that the previous record's reason be preserved. Rationale: nothing reports by reason, so a lookup table would be unused complexity. Accepted trade-off: reasons are not analysable and may be inconsistent.
- Recommended default: required free text, trimmed, 1–255 characters.
- Reason: the brief requires preserving "its reason"; nothing reports by reason, so no controlled vocabulary.
- Trade-off: not analysable; typos/inconsistency.
- Blocks: Phase 3, 4.

**DR-13 — Country and department grouping behaviour** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Group current compensation by current employee country/department; keep no transfer history or as-of group reports. Country changes do not change salary currency. This follows the lifecycle exclusions.
- Recommended default: analytics group by the employee's current country/department against the current salary; no history of country/department; no as-of group analytics; a country change does not alter salary currency.
- Reason: no requirement for history; nothing is stored redundantly.
- Trade-off: past reports cannot be reproduced after a transfer.
- Blocks: Phase 7.

**DR-14 — `reference_data` endpoint and `currencies` table** `[APPROVED (delegated)]`
- **Decision (Approved under delegated authority (owner instruction of 17 November 2026 authorising low-risk MVP decisions supported by the requirements and technical evidence); **owner review is requested at G1 sign-off**.)** Keep both. The `currencies` table (`code varchar(3)` primary key with the DR-21 CHECKs, `name`) is the foreign-key target for `salary_records.currency_code` and `exchange_rates.from_currency`/`to_currency`; `GET /api/v1/reference_data` returns the option lists the SPA needs. Neither is an assessment requirement (they are optional enhancements, `architecture.md` §0). Rationale: departments are database rows addressed by numeric id, so the SPA cannot hard-code its filter options; without a `currencies` table the same three-letter list would be duplicated in CHECK constraints on three columns, and the endpoint's `has_rate` needs a currency list anyway. The table is built in Phase 3 and the endpoint in Phase 5. `low_sample_threshold` is added to the response only when DR-08 is approved. Accepted trade-off: one more table and endpoint than the strict minimum. This also settles the Phase 3 scope question in §7.2 (U-6).
- Recommended default: keep both (optional enhancements).
- Reason: FK integrity for salary/rate currency; avoids hard-coding option lists in the frontend. `has_rate` is defined precisely in `api-contracts.md`.
- Trade-off: one more table and endpoint than the minimum. Alternative: a CHECK/constant list and constants in the SPA.
- Blocks: Phase 3, 5, 8, 9.

**DR-15 — Median definition** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Use the middle value for odd counts and the exact numeric mean of the two middle values for even counts; round to 2 dp at output, half away from zero. Keep the ranked SQL method and empty-group contract in domain-decisions.md §10; no float coercion.
- Recommended default: statistical median computed exactly in `numeric`: middle value for odd n; arithmetic mean of the two middle values for even n; rounded to 2 dp at output (half away from zero). Same definition for organization, country, department.
- Reason: `percentile_cont` coerces to `double precision`, which the money rules forbid.
- Trade-off: needs a ranking query (window functions) rather than a single aggregate call.
- Blocks: Phase 7.

**DR-16 — Analytics scope additions** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Keep country, department and job_level filters, per-currency local_totals on country rows only, and status_counts for all statuses in the filtered population. These give concrete meaning to the existing selected-group and local-currency requirements; they add no infrastructure.
- Recommended default: optional `country`, `department`, `job_level` filters; `local_totals` (per currency) on country rows only; `status_counts`.
- Reason: gives meaning to "selected groups" and "local-currency amounts where relevant", both undefined in the brief.
- Trade-off: extra query/payload complexity for thinly specified requirements; could be cut to by-country/by-department only.
- Blocks: Phase 7, 9.

**DR-17 — Seed dataset parameters** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Keep curated in-repo names, fixed RNG seed 20261117, anchor 2026-11-01, illustrative rates in domain-decisions.md §3.2, and the existing deterministic generator parameters. Its synthetic status weights are 9200 active / 300 on_leave / 500 terminated, non-home-currency selection probability 3%, and closed-history weights 60/25/10/5 for 0/1/2/3 records. These are demo-generation parameters, not business distributions or guaranteed random outcome counts. Keep six countries (including shared EUR), nine departments and levels 1–7; verify a group below 10, exactly 10,000 employees and identical fingerprints on reruns. Deployment must be on or after the anchor date. This accepts the existing low-risk dataset design without rewriting seed code; actual seed verification remains outstanding in this audit.
- Recommended default: curated in-repo name lists (no Faker), fixed RNG seed, fixed anchor date ≤ deployment date, illustrative fixed rates, status proportions fixed in code, at least one group below the low-sample threshold, countries sharing a currency.
- Reason: byte-identical reruns; no dependency.
- Trade-off: less realistic names than Faker.
- Blocks: Phase 6.

**DR-18 — Presentation and addressing conventions** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Keep numeric employee IDs in URLs, UTC timestamps, default page size 25 and maximum 100, and the existing API sort allow-list. Reusing the documented contract avoids new addressing or pagination machinery.
- Recommended default: employees addressed by numeric `id` in URLs; timestamps displayed in UTC; page size default 25, max 100; sort allow-list as in `api-contracts.md`.
- Trade-off: sequential ids are enumerable (irrelevant for synthetic data); UTC display is unfamiliar to some users.
- Blocks: Phase 5, 8, 9.

**DR-19 — Unpaginated salary history** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Keep complete newest-first unpaginated salary history as the documented MVP trade-off. Do not claim a maximum; retain the Phase 10 long-history measurement and pagination follow-up if needed.
- Recommended default: return the full history inside `GET /employees/:id` as a conscious MVP trade-off. No maximum number of revisions is guaranteed.
- Reason: smallest API; seeded histories are short.
- Trade-off: payload grows linearly with revisions. Revisit (e.g. a paginated history endpoint) if Phase 10 measurement with a long-history fixture shows a problem.
- Blocks: Phase 5.

### 3.4 Infrastructure decisions

**DR-20 — PostgreSQL provider and `btree_gist` availability** `[APPROVED — design]` `[SELECTED — Neon Free plan; hosted verification PENDING]`
- **Decision — design (approved 17 November 2026, owner instruction):** PostgreSQL `btree_gist`; an exclusion constraint `EXCLUDE USING gist (employee_id WITH =, tstzrange(effective_from, effective_to, '[)') WITH &&)`; and the partial unique index on `employee_id WHERE effective_to IS NULL` is kept. The partial unique index protects only against multiple open-ended records; the exclusion constraint prevents **all** overlapping intervals, including historical ones. The local spike verified this on PostgreSQL 14.25 (§12).
- **Decision — provider (Approved under delegated authority (owner instruction of 17 November 2026 authorising low-risk MVP decisions supported by the requirements and technical evidence); **owner review is requested at G1 sign-off**.)** **Neon, Free plan**, direct (non-pooled) connection. Evidence is **documentary only** (§12.4): Neon's own extension table lists `btree_gist` for PostgreSQL 14–18 (1.6 / 1.7 / 1.7 / 1.7 / 1.8), and Neon's `btree_gist` page documents `CREATE EXTENSION IF NOT EXISTS btree_gist;` and an `EXCLUDE USING GIST (room_id WITH =, booking_period WITH &&)` overlap constraint. Render (free database expires after 30 days), Heroku, Supabase, Railway and AWS RDS were evaluated and not selected (§12.4). **Not verified:** no account or database was created, so extension creation, the exclusion constraint and the application role's privileges have **not** been tested on Neon. The owner or a separately authorized operator runs the short probe in §12.5; DR-20 is not marked verified until its result is recorded here. Rationale: Render, Heroku and RDS also document `btree_gist`, but Neon is the candidate that combines documented support (including the exact exclusion-constraint pattern) with a documented $0 plan whose listed limits include no expiry, and with no operational weight beyond a connection string. Known limitations and deployment implications: §12.4. Choose PostgreSQL **17** (or 18) when creating the project: the spike ran on 14.25, which is the final release of an end-of-life major (§12.4).
- Question: which PostgreSQL hosting option will be used, and does it support `CREATE EXTENSION btree_gist`? Alternatively, is the weaker fallback approved?
- Recommended default: the owner selects the intended database provider **before Phase 3** and verifies the extension on it (a throwaway database is enough); the exclusion constraint stays in the design. Local development also needs the extension (checked in the Phase 2 spike).
- Reason: Phase 3 builds the constraint; discovering at Phase 11 that the host lacks it would force rework.
- Fallback (needs its own explicit approval): partial unique index + employee row lock + application overlap validation. This gives a **weaker guarantee**: bugs or manual SQL could create overlapping closed intervals, which the database would no longer reject.
- Trade-off: choosing the database provider early constrains the later application-hosting choice (DR-22) only mildly.
- Blocks: Phase 3 (gate G1).

**DR-21 — `schema.rb` versus `structure.sql`** `[APPROVED]`
- **Decision (approved 17 November 2026, owner instruction):** Use Rails `schema.rb`; the real application does not switch to `structure.sql`. The isolated spike showed that the extension, exclusion constraint, partial unique index and CHECK constraints survive a `schema.rb` dump and reload. The one loss was PostgreSQL `char(n)`, which the dump turns into `varchar(n)`, so the approved schema uses `varchar(2)` for country codes and `varchar(3)` for currency codes with explicit length and format CHECK constraints, and does not depend on `char(n)` semantics. Limitation: the spike schema itself used `char(n)`; the `varchar` + CHECK variant is verified by the Phase 3 specs and the fresh-database setup checks, not by the spike (§12).
- Recommended default: `schema.rb`, **if** the Phase 2 capability spike shows that the pinned Rails version dumps and reloads the extension, CHECK constraints, partial unique index and exclusion constraint faithfully. Otherwise `structure.sql`.
- Reason: `schema.rb` is simpler to read and review; correctness of the dump matters more than convenience.
- Trade-off: `structure.sql` is more complete but noisier and needs matching `pg_dump` versions.
- Blocks: Phase 3.

**DR-22 — Hosting provider, deployment topology and CORS handling** `[APPROVAL]`
- Owner note (17 November 2026): `rack-cors` stays installed for local development only (DR-24). The database provider is now selected (DR-20: Neon), but Neon hosts only the database: the application host, topology and production CORS policy are still open and are decided at gate G5 (ideally before Phase 8).
- Question: where are the SPA, API and database hosted, how are they arranged, and — if the SPA and API are on different origins — how is CORS configured (including production configuration of the existing `rack-cors` gem)?
- Recommended default: two deployables (static SPA + Rails API) and one managed PostgreSQL, unless the chosen provider makes same-origin serving simpler. CORS, if needed, is restricted to an explicit allow-list of configured origins (never a wildcard) and must permit the `Authorization` header. Reuse the already approved `rack-cors` if the selected production topology needs CORS; approve its production configuration under this decision. Same-origin serving avoids CORS. No replacement middleware or new dependency is needed. The assessment specifies no provider.
- Reason: conventional, independent deploys. Same-origin avoids CORS entirely.
- Trade-off: cross-origin needs an explicit allow-list, preflight for the `Authorization` header and explicit middleware configuration.
- Blocks: Phase 11 (gate G5); decide before Phase 8 if possible because it fixes the API base URL and CORS needs.

**DR-23 — Write-endpoint rate limiting** `[APPROVED (delegated)]`
- **Decision (Codex, 17 November 2026, current owner delegation; owner review pending):** Add no application rate-limiting dependency for the synthetic demo. Use platform limits if available after DR-22; otherwise accept the documented brute-force risk with a long random write passphrase. No rack-attack, Redis or workers. Reassess before using real data or expanding access.
- Question: is throttling of the write endpoint required for the public demo, and if so by what means (platform-level limits, or the `rack-attack` gem)?
- Recommended default: add nothing now. Use platform-level throttling if the chosen provider offers it; otherwise accept the risk for a synthetic demo with a long random passphrase. Treat `rack-attack` as opt-in and approve it here before it is added.
- Reason: avoid unapproved dependencies; risk is bounded by synthetic data.
- Trade-off: without throttling the passphrase is brute-forceable.
- Blocks: Phase 5 (gate G3); Phase 11 verification applies only if throttling is approved.

**DR-24 — Baseline bootstrap dependencies** `[APPROVED]`
- **Decision (approved 17 November 2026, owner instruction):** Baseline: Rails + PostgreSQL adapter + RSpec; React + TypeScript + Vite, a client-side router (`react-router-dom` 7), TanStack Query, **Tailwind CSS 4** (approved as the styling approach), Vitest + React Testing Library. **Removed** as unneeded: `pagy` (the pagination contract is implemented directly), `faker` (the seed uses deterministic curated data, DR-17), `lucide-react`. **Kept:** `rack-cors` for local development only; the production CORS policy and topology remain open under DR-22. Generator-provided and plan-implied tooling (`factory_bot_rails` for Phase 3 factories, RuboCop omakase, Brakeman, bundler-audit, ESLint/typescript-eslint, jsdom, testing-library jest-dom/user-event) is treated as part of the scaffold; the owner is asked to confirm that reading (§11).
- Recommended default: Rails + PostgreSQL adapter + RSpec; React + TypeScript + Vite, a client-side router, TanStack Query, Tailwind, Vitest + React Testing Library. Nothing else (no pagination/serializer gem, no Faker, no chart library, no auth gem).
- Reason: all but the router are already the owner-directed stack; the router is needed for three views.
- Trade-off: a chart library and Faker would improve visuals/data realism at the cost of dependencies.
- Blocks: Phase 2 (gate G0).

## 4. Design summary (details live in the ranked documents)
Six tables (`countries`, `departments`, `currencies`, `employees`, `salary_records`, `exchange_rates`); append-only salary history; revision = authenticate → lock employee → read current record → token check → eligibility → validate and no-op → one clock read → FX lookup by that timestamp → conflict check → close previous + insert new in one transaction; PostgreSQL exclusion constraint for overlap prevention (DR-20); `fx_rate` snapshot on each record (DR-05); computed SQL values from one shared fragment; exact `numeric` median (DR-15); offset pagination; CSV export reusing the directory query with deterministic formula-injection sanitization; shared write passphrase (DR-02).

## 5. Alternatives considered and rejected

| Topic | Rejected | Reason |
|-------|----------|--------|
| Effectivity | Dates with a one-revision-per-day rule | Cannot fix a same-day typo; needs a time-zone definition (DR-01) |
| Overlap integrity | Application validation only; triggers | Weaker, or more bespoke code, than one constraint (but see DR-20 fallback) |
| FX storage | FK `exchange_rate_id` on records | Depends on rate rows never being edited; extra join |
| FX storage | Single rate on the country row | Wrong: currency ≠ country; rates vary over time |
| Rounding | Round only at the end | Totals not reproducible from visible rows (DR-06) |
| Median | `percentile_cont` | Coerces `numeric` to `double precision` (violates money rules) |
| Median | Cast to `double precision` deliberately | Same violation |
| Derived data | Stored `annual_*`, materialized view, DB view | Second source of truth; DB view forces `structure.sql` |
| Pagination | Keyset | Not needed at 10,000 rows; random page jumps wanted |
| Write protection | Basic auth; session login; open writes + reset; read-only | See `architecture.md` §9.2 |
| Status type | Native PG enum | Harder to evolve; CHECK suffices |
| Names | Faker | Dependency; output drift between versions |
| Infrastructure | Redis, Elasticsearch, background jobs, microservices, read replicas | No measured need |
| Frontend | Next.js | A separate API with an SPA is sufficient; the assessment accepts React or Next |
| Charts | Chart library | Tables and simple bars suffice unless approved (DR-24) |

## 6. Risks and edge cases

| ID | Risk / issue | Mitigation / status |
|----|--------------|---------------------|
| R-1 | SQL and Ruby both implement annualization/conversion/rounding and could drift | One SQL fragment for set queries; Ruby for single records; **parity tests** on shared fixtures (Phase 4, re-run in Phase 7) |
| R-2 | Seed uses bulk insert, bypassing model validations | DB constraints still apply; post-seed verification queries |
| R-3 | Hosting database may lack `btree_gist`, or the application role may lack the privilege to create it | Neon (selected) documents `btree_gist` for PostgreSQL 14–18 but nothing was tested on it (§12.4). Owner runs the probe in §12.5 before G1 sign-off; if the migration role cannot create the extension, enable it once as the owner role (`enable_extension` is `IF NOT EXISTS`, so the migration then does nothing) |
| R-4 | `schema.rb` may not faithfully dump all constraints | Spike: extension, exclusion constraint, partial index and CHECKs preserved; `char(n)` → `varchar(n)` (DR-21 uses `varchar` + CHECKs). Phase 3 re-verifies the `varchar` + regex-CHECK variant |
| R-5 | Shared passphrase: no identity/audit, brute-forceable without throttling | Accepted for synthetic demo; fail closed; strong passphrase; DR-23 |
| R-6 | Open reads on a salary application | Acceptable only because data is synthetic; a demo decision, not a pattern |
| R-7 | Public CSV export (10,000 rows) can be abused | Batched streaming; platform limits; unmeasured |
| R-8 | Microsecond truncation: Ruby nanoseconds vs PostgreSQL microseconds could make `effective_to ≠ next.effective_from` | Truncate once, reuse the same value; test boundary equality (Phase 4) |
| R-9 | Median coercion to `double precision` if `percentile_cont` is used | Excluded by design (DR-15); regression test with a large-magnitude half-cent case |
| R-10 | Group medians in USD across countries are easily misread | Headcount always shown; `low_sample`; caveat copy; no "inequity", "attrition", compa-ratio wording |
| R-11 | Country/department changes have no history | DR-13; no as-of group analytics |
| R-12 | `ILIKE '%term%'` performance unmeasured | Measure in Phase 10; `pg_trgm` needs approval |
| R-13 | Terminated/on-leave employees exist only via seed (no workflow) | Acceptable; rules tested through fixtures |
| R-14 | Clock skew between app instances could trigger `revision_conflict` | Possible even on one instance under clock adjustment or the same microsecond; read after the lock and reject a non-increasing timestamp rather than assume a monotonic wall clock |
| R-15 | Natural-key primary keys (`code`) differ slightly from Rails convention | Supported; stored as `varchar(2)`/`varchar(3)` (DR-21); confirm in Phase 3 |
| R-16 | Frontend types drift from the API contract | Contract cross-check in Phase 10 |
| R-17 | Fixed illustrative FX rates mistaken for real rates | Labelled in UI and API notes |
| R-18 | Unpaginated salary history grows with revisions (DR-19) | Conscious trade-off; measure with a long-history fixture in Phase 10 |
| R-19 | Passphrase leaks via logs/proxies (header logging) | Never log `Authorization`; verify in Phase 11 |
| R-20 | The decimal-string rules reject some inputs users might type (commas, spaces) | UI normalizes display input before sending; server stays strict |
| R-21 | CSV formula injection: RFC 4180 quoting alone does not prevent it, and prefixing is a mitigation, not a guarantee for every spreadsheet application | Deterministic sanitization policy and required test table in `api-contracts.md` §5; exported files treated as untrusted by consumers |
| R-22 | In-memory passphrase is lost on reload/tab close but persists across in-app navigation | Documented accurately (`architecture.md` §9.3); discarded on `401`; short re-entry friction accepted |
| R-23 | The spike ran on PostgreSQL 14.25, the final release of a major that reached end of life on 12 November 2026 (postgresql.org versioning policy) | Choose a supported major (17 or 18, both listed by Neon) for the hosted database and run the Phase 3 specs on the same major locally; re-run the §12.1 probes there. Only PostgreSQL 14 is installed locally today |
| R-24 | Neon's Free plan suspends compute after 5 minutes of inactivity and caps storage, compute hours and transfer; the first request after idle may be slow or fail | Not measured. Check first-request behaviour in Phase 10/11 and warm the database before the demo video; storage for the 10,000-row dataset is expected to be far below 1 GB but is unmeasured |

## 7. Conflict log

### 7.1 Conflicts found in the first drafts and resolved in this review

| # | Conflict | Resolution |
|---|----------|------------|
| C-1 | Precedence: `copilot-instructions.md` ranked requirements > domain > architecture and ignored the assessment; `domain-decisions.md` claimed to "win" generally | One hierarchy (§1) used everywhere |
| C-2 | Architecture: out-of-range page → 400; API: → 200 empty | Malformed/zero/negative page → 400; page beyond last → 200 with empty `data` |
| C-3 | Architecture: export always ordered by `employee_number`; API: accepts sort | Export reuses directory filters and sort/direction; default `employee_number`; same tie-breaker; no paging |
| C-4 | `percentile_cont` over `numeric` money (coerces to `double precision`) | Exact `numeric` median (DR-15) |
| C-5 | Revision flow called the clock/"today" independently for the rate lookup and the writes | One timestamp, truncated once, used for lookup, closure and insert |
| C-6 | Phase 3 needs `btree_gist`; hosting verified only at Phase 11 | DR-20 gate before Phase 3; Phase 2 spike |
| C-7 | API called unpaginated history "bounded in practice" | Reworded as an intentional trade-off (DR-19); no maximum claimed |
| C-8 | Review claimed assessment constraints were unverified because the PDF is not in the repo | Owner-verified constraints used (§2.1) |
| C-9 | Pending decisions stated as invariants in Copilot instructions (`active`-only totals; timestamp semantics; rounding) | Instructions separate approved invariants from pending decisions and require a register check |
| C-10 | Error code `employee_not_active` (**obsolete name**) contradicted the proposal that `on_leave` may be revised | Renamed `employee_not_eligible`; eligibility follows DR-03. The old name must not be used anywhere except in this historical row |
| C-11 | Phase 1 said "approval" but Phases 2–3 had no explicit approval gates | Gates G0–G5 |
| C-12 | Architecture said the demo passphrase may live in `sessionStorage`; security guidance prefers memory only | In-memory only |
| C-13 | Documents implied Rails/React/Next/PostgreSQL were all assessment requirements | Classified in §2.2: only "Rails preferred", "React or Next", "a relational database" come from the assessment |
| C-14 | Phase 2 required a health endpoint that was not in the API contract | Use the framework-provided health route, outside the versioned API (no new contract endpoint) |
| C-15 | A trade-off row said "the brief says to avoid" caches/queues | Reworded: project guidance, not the brief |

### 7.2 Conflicts that need owner input

| # | Conflict | Treatment |
|---|----------|-----------|
| U-1 | The owner's review asks that the timestamp-based revision flow and the per-employee rounding rule be applied consistently, while also listing DR-01 and DR-06 as unresolved | Resolved: DR-01 owner-approved; DR-06 now decided under current delegation |
| U-2 | The brief says totals include "active employees" without defining "active"; status set is not specified | Resolved by owner-approved DR-03 |
| U-3 | The brief asks for local-currency amounts "where relevant" and comparisons "for selected groups" without defining either | Resolved by delegated DR-16 |
| U-4 | The assessment does not name a hosting provider, yet Phase 3 requires `btree_gist` | Provider selected: Neon (DR-20); hosted runtime verification and owner sign-off remain open |
| U-5 | Export includes every status matching the filters, while dashboard totals are active-only | Behaviour kept; UI note; reconciliation only with `status=active`, matching country/department scope, no `job_level` or `q` |
| U-6 | The owner's Phase 3 scope lists `currencies` among "six approved tables", while DR-14 was open | **Resolved** by DR-14 (delegated, 17 November 2026): the table and the endpoint are both kept. Owner review requested |
| U-7 | G1 requires the hosted provider to be chosen and `btree_gist` verified there before Phase 3; the owner had recorded hosted compatibility as a deployment prerequisite | **Partly resolved:** provider selected (Neon). The gate wording is **unchanged**: verification on the hosted database is still required and is **pending** (§12.5). The owner may instead explicitly move it to a pre-Phase-11 prerequisite and accept risk R-3 |

### 7.3 Corrections made in the final consistency audit

Each was verified against the actual text of the seven documents before and after editing.

| # | Finding | Correction |
|---|---------|------------|
| C-16 | The revision step order in `domain-decisions.md` §7, `architecture.md` §6.3, `api-contracts.md` and the plan read the clock **before** eligibility/validation, differing from the owner's specified 12-step order | All four now follow the owner's order: authenticate → lock → read current record → token → eligibility → validate and no-op → one clock read → FX lookup by that timestamp → conflict check → close → insert → commit. Error precedence is unchanged |
| C-17 | DR-23 combined two topics (rate limiting and `rack-cors`/CORS) and was listed under two different gates | DR-23 is now write-endpoint rate limiting only (gate G3). CORS handling and `rack-cors` moved into DR-22 (gate G5). No decision IDs were added or renumbered; every DR-nn is defined exactly once |
| C-18 | ER diagram drew `EMPLOYEES ||--|{ SALARY_RECORDS` (one-or-more), implying the database guarantees every employee has a salary record | Now `||--o{` with an explicit note that "exactly one open record" is an application and seed invariant |
| C-19 | CSV policy only covered cells starting with `= + - @` | Deterministic sanitization policy (leading whitespace/control characters, TAB/CR/LF, numeric columns untouched, RFC 4180 applied afterwards) with a required test table; states that quoting alone does not prevent formula injection |
| C-20 | Documents said the in-memory passphrase is "cleared when the user leaves the application", which is not true for client-side route changes | Reworded accurately: lost on reload/tab close, not cleared by in-app navigation, discarded on `401` |
| C-21 | DR-04 (stale-edit token) status marker was missing from the revision procedure, architecture sequence and plan | Marked as proposed/pending in all of them, with the behaviour if it is resolved as optional |
| C-22 | "Blocks" lines in the register disagreed with the plan's "Blocked by" lines (DR-02, 03, 04, 05, 08, 09, 11, 16, 18), and Phase 6 started before DR-07 (a G2 item) was required | Register and plan reconciled; Phase 6 prerequisites now include DR-07 |
| C-23 | API field definitions were incomplete; `total_pages` for an empty result was undefined; 500 text only said "no internals" | Missing field rules added; `total_pages = 0` defined; 500 policy spelled out (no exception text, class names, backtraces, SQL or echoes) |
| C-24 | Assessment traceability omitted the one-page requirements document and documented AI-assisted work, both stated by the owner | Added to §2.1, §10, `architecture.md` §0 and Phase 12 |
| C-25 | Domain §11 said "the approved statuses (DR-03)" although DR-03 is pending; `low_sample` and `low_sample_threshold` lacked their pending marker | Reworded; `[APPROVAL DR-08]` added |
| C-26 | Seed formula consistency was not stated | Seed uses the same lookup/calculation rules (stated in domain §3.3 and architecture §2) |

### 7.4 Changes made in the 17 November 2026 update

| # | Change |
|---|--------|
| C-27 | DR-01, DR-03, DR-04, DR-11, DR-20 (design), DR-21 and DR-24 recorded as approved; the other documents drop the working-default wording for them. DR-05, DR-09, DR-12, DR-14, the rest of DR-20 and all later-gate items stay open. |
| C-28 | Spike results recorded in §12 with what was tested, what was not, and what the hosting provider must still verify. |
| C-29 | `architecture.md` §2 frontend structure replaced by the actual `app/`, `components/`, `features/`, `lib/`, `types/` layout, and the Rails API-only structure documented. |
| C-30 | Country and currency codes changed from `char(2)`/`char(3)` to `varchar(2)`/`varchar(3)` with length and format CHECKs (DR-21). |
| C-31 | `pagy`, `faker` and `lucide-react` removed; `rack-cors` limited to local development pending DR-22. |
| C-32 | Implementation plan: Phase 2 recorded as completed and verified; Phase 3 remains blocked by the open G1 items. |

### 7.5 Changes made in the second 17 November 2026 update

| # | Change |
|---|--------|
| C-33 | DR-05, DR-09, DR-12 and DR-14 decided under delegated authority and recorded with source, rationale and accepted trade-offs; `architecture.md`, `domain-decisions.md`, `api-contracts.md`, `implementation-plan.md` and the Copilot instructions updated to match. |
| C-34 | DR-20 provider selected (Neon, Free plan) on documentary evidence; evaluation of six providers recorded in §12.4; verification probe added in §12.5; hosted verification left **pending**. |
| C-35 | `salary_records.reason` becomes `varchar(255)` with the non-blank CHECK (previously length was validated in the application only). |
| C-36 | Risks R-23 (spike ran on an end-of-life PostgreSQL major) and R-24 (Neon Free plan behaviour) added; U-6 resolved, U-7 partly resolved. |
| C-37 | The dependency decisions (DR-24) were already applied to the manifests and lockfiles; verified, not repeated. |

## 8. Self-critique

**Tensions in the design**
1. "Prevent overlapping salary periods" with immediate-only revisions means overlap can arise only from concurrency or bugs; the constraint is defence in depth.
2. Per-record rate snapshots can mix rate dates in totals if rates ever vary (DR-05).
3. The exclusion constraint subsumes the partial unique index; the index is kept for the current-salary lookup and a clearer error. Neither guarantees an open record exists.
4. An exact median via window functions costs more SQL than one aggregate call; acceptable at 10,000 rows, to be measured.

**Historical simplification candidates (retained decisions are not reopened):** `on_leave` (DR-03), `local_totals` and the `job_level` analytics filter (DR-16), `reference_data` and `currencies` (DR-14), the mandatory token (DR-04, kept for real lost-update risk), the identity `USD→USD` rate row.

**Missing business rules (not invented):** salary ranges per level/country; approval workflows; rehires/transfers/multiple jobs; retention/audit requirements; currencies with ≠ 2 decimals; response-time targets (none specified; none claimed).

**Checked and not claimed:** the partial unique index is not described as preventing all historical overlaps; peer medians are not compa-ratios; outliers are not evidence of inequity or attrition; no performance numbers, stakeholder answers or assessment requirements are invented; `percentile_cont` over `numeric` was confirmed to return `double precision` on PostgreSQL 14.25 in the spike (§12); the existing Phase 7 regression specs must still be executed successfully in the real application.

## 9. Proposed changes to `docs/requirements.md` (NOT applied; need explicit approval)

*Update 17 November 2026:* DR-01 and DR-03 are now approved decisions, but the proposed wording changes below are still **not applied** to `docs/requirements.md`; editing it needs a separate explicit approval.
1. Define the employment status set and which count as "active" (DR-03).
2. State that salary effective values are server-set timestamps (DR-01), if approved.
3. Clarify "local-currency amounts where relevant" (per employee and on country rows) and "selected groups" (filter-selected) (DR-16).
4. Mention a shared demo write passphrase under "demo-only access protection" (DR-02).
5. Define the median (DR-15).

## 10. Assessment traceability

| Assessment item | Category | Where addressed |
|-----------------|----------|-----------------|
| 10,000-employee organization; HR Manager | Assessment | `requirements.md`; Phase 6 seed |
| One-page requirements document | Assessment | `docs/requirements.md` (exists) |
| Backend aligned with role; Rails preferred | Assessment (preference) | Rails API (technology choice) |
| ReactJS or NextJS | Assessment | React SPA (technology choice) |
| Relational database | Assessment | PostgreSQL (technology choice) |
| Seed script, 10,000 employees | Assessment | Phase 6 |
| Fully functional deployed software | Assessment | Phase 11 (provider unspecified by assessment) |
| Video demonstration | Assessment | Phase 12 (duration unspecified) |
| Meaningful, fast, deterministic tests | Assessment | Every phase; `copilot-instructions.md` |
| Structure, readability, maintainability | Assessment | `architecture.md`; per-phase review |
| Incremental Git commits | Assessment | Commit boundaries per phase |
| Supporting artifacts (requirements, diagrams, design notes, trade-offs, performance) | Assessment | `docs/`, `.github/`, Phase 10 measurements, Phase 12 README |
| Documented AI-assisted work / AI prompts | Assessment | `.github/prompts/`, `.github/copilot-instructions.md`, Phase 12 README section |
| Commit to a Git repository; reply to the same email with the repository link | Assessment | Phase 12 |
| Deadline, hosting provider, video duration | **Unspecified** | Owner to confirm if relevant |

## 11. Owner approval checklist

The boxes distinguish recorded decisions from outstanding owner review; a delegated decision is not evidence of explicit gate sign-off. Only the gates needed by the next phase must pass; later gates do not block G1. Requirements wording suggestions and assessment-PDF publication are optional, not G1 prerequisites.

**G0 — before Phase 2**
- [ ] Reviewed the six documents and this register; accept scope and exclusions. *(Not recorded as a separate approval; please confirm.)*
- [x] DR-24 baseline dependency list (approved 17 November 2026; confirm the tooling reading in DR-24).
- [x] Phase 2 (bootstrap only) executed and verified; the scaffold was created and directed by the owner.

**G1 — before Phase 3**
- [x] DR-01 timestamp vs date effectivity (approved).
- [x] DR-03 statuses, active-payroll population, revision eligibility (approved).
- [x] DR-05 FX snapshot semantics (delegated; owner review requested).
- [x] DR-09 terminated-employee handling (delegated; owner review requested).
- [x] DR-11 salary amount upper bound: `1000000000.00` (approved).
- [x] DR-12 required free-text reason (delegated; owner review requested).
- [x] DR-14 `currencies` table / `reference_data` endpoint: keep both (delegated; owner review requested).
- [ ] DR-20 database provider chosen and `btree_gist` verified (or the weaker fallback explicitly approved). *(Design approved and locally verified; provider **selected**: Neon Free plan; **hosted verification pending** — run §12.5 and record the result; then tick.)*
- [x] DR-21 `schema.rb` (approved; `varchar` codes with CHECKs).

- [ ] Owner explicitly signs off the delegated G1 decisions, provider selection and hosted result.

**G2 — before Phase 4**
- [x] DR-04 mandatory token (approved). · [x] DR-06 rounding policy. · [x] DR-07 currency vs country. · [x] DR-10 no-op rejection.

**G3 — before Phase 5**
- [x] DR-02 write protection. · [x] DR-18 conventions. · [x] DR-19 unpaginated history. · [x] DR-23 write-endpoint rate limiting.

**G4 — before Phases 6–7**
- [x] DR-17 seed parameters. · [x] DR-08 low-sample threshold. · [x] DR-13 grouping behaviour. · [x] DR-15 median definition. · [x] DR-16 analytics scope.

**G5 — before Phase 11**
- [ ] DR-22 hosting, topology and CORS handling (including production use/configuration of the existing `rack-cors`).

**Other**
- [ ] Requirements changes in §9: accept, reject or defer each.
- [ ] Decision on whether the assessment PDF may be committed (default: it is not).

## 12. Database compatibility spike record (DR-20, DR-21)

**What it was.** A throwaway experiment on 17 November 2026, run in an isolated temporary copy of the backend (`/tmp/acme-spike`) against temporary databases (`acme_spike_*`), all deleted afterwards. **It was not run in the real application**: no spike migration, schema file, spec or database was added to the repository, and at the time the real `backend/db/` contained only the seed stub. The current audit found later pre-existing migrations and `schema.rb`; they are not artifacts of that isolated spike. Environment: PostgreSQL **14.25** (Homebrew, aarch64-apple-darwin), `pg_dump` 14.25, Ruby 4.0.9, Rails 8.1.4.1.

**Method (commands).** `createdb` for each temporary database; a throwaway migration creating the six tables from `architecture.md` §4 plus `enable_extension "btree_gist"`, the partial unique index, the exclusion constraint and the CHECKs; `bin/rails db:migrate`; inspect `db/schema.rb`; `bin/rails db:schema:load` into a second database and compare `pg_dump -s` output of the two; repeat with `config.active_record.schema_format = :sql` and `db:schema:load`; RSpec behavioural probes against an empty test database; `db:drop`/`db:create`/`db:schema:load` and `db:prepare` on a missing database; a `NOSUPERUSER` role owning a database runs `CREATE EXTENSION btree_gist`.

### 12.1 Tested and passed
| Check | Result |
|-------|--------|
| `btree_gist` extension creation (`enable_extension`) | Succeeded (version 1.6) |
| Exclusion constraint and partial unique index creation | Succeeded |
| `schema.rb` dump | Contains `enable_extension "btree_gist"`, `t.exclusion_constraint` with the `tstzrange` expression, the partial index with its `where:`, and every `t.check_constraint` |
| `schema.rb` dump and reload (`db:schema:load`, then `pg_dump -s` comparison) | Extension, exclusion constraint, partial unique index and CHECKs preserved. Differences: `char(n)` columns reloaded as `varchar(n)`; CHECK expressions re-rendered with equivalent casts. **This is why the approved design uses `varchar` with CHECKs (DR-21).** |
| `structure.sql` alternative | Preserved `char(n)`; not adopted |
| Empty test database | Populated automatically by `maintain_test_schema!` when RSpec started |
| `db:drop`, `db:create`, `db:schema:load`; `db:prepare` on a missing database | Both succeeded; the exclusion constraint existed afterwards |
| Half-open adjacent intervals `[a,b)`, `[b,c)`, `[c,∞)` | Accepted |
| Overlapping historical intervals | Rejected (`PG::ExclusionViolation`) |
| Partial unique index alone with the exclusion constraint temporarily dropped | A historical overlap was **accepted**, proving the index alone does not prevent it |
| Second open-ended record | Rejected; the exclusion constraint fired (`PG::ExclusionViolation`) |
| `effective_to <= effective_from` | Rejected (`PG::CheckViolation`) |
| Insert-before-close | Failed (second open record); **close-then-insert succeeded** |
| Amount `0` and negative | Rejected by CHECK |
| Amount `1000000000000.00` (beyond `numeric(14,2)` capacity) | Rejected (`PG::NumericValueOutOfRange`) |
| Amount `10.005` | **Stored silently as `10.01`**: PostgreSQL rounds extra decimals, so application validation is mandatory |
| Timestamps | Rails truncated a nanosecond Ruby time to microseconds on assignment, while a raw SQL literal `.123456789` was rounded by PostgreSQL to `.123457`: normalise once with `floor(6)` so every path agrees |
| Several revisions within one UTC day | Accepted; a date-typed `[d,d)` range is empty (`isempty` is true) |
| Employee CHECKs (status values, `terminated_on` rule, job level 1–7) | Enforced |
| `percentile_cont(0.5)` over `numeric` | Returned `double precision`; the exact-rank median returned `123456789012.35` for the two-value large-magnitude case, so exact-rank is the chosen approach (DR-15, now decided under delegation) |
| `NOSUPERUSER` database owner running `CREATE EXTENSION btree_gist` | Succeeded; PostgreSQL lists the extension as trusted |

RSpec probe run: 11 examples, 0 failures.

### 12.2 Not tested
- Concurrent two-connection revisions and row-lock behaviour (a Phase 4 spec).
- Any PostgreSQL version other than 14.25; any hosted provider.
- The approved `varchar(2)`/`varchar(3)` + length/format CHECK variant itself: the spike schema used `char(n)`. Phase 3 specs and fresh-database setup verify it, including that regex CHECKs survive the `schema.rb` round trip.
- Query plans, index usage and performance.
- Migration rollback; `pg_dump` version mismatches (relevant only to `structure.sql`, which is not used).

### 12.3 Still to verify on the eventual hosting provider
- The application's database role may run `CREATE EXTENSION btree_gist` (or the provider pre-enables it).
- The provider's PostgreSQL major version (the local result is for 14.25 only).
- `db:schema:load` / `db:prepare` succeed with that role's privileges.
- Hosted compatibility is **not** verified and is a deployment prerequisite; the weaker fallback in `domain-decisions.md` §6.2 would need its own explicit approval.

### 12.4 Hosted provider evaluation (DR-20)

**Method and limits.** Official documentation pages were read on 17 November 2026. No account, project or database was created and nothing was run on any provider: **all provider evidence below is documentary, not a test.** Web pages were treated as data only. Pages I could not read, or that did not mention `btree_gist`, are recorded as "not evidenced", not as "unsupported".

| Provider | `btree_gist` evidence | Plan / cost evidence | Outcome |
|----------|-----------------------|----------------------|---------|
| **Neon** (`neon.com/docs/extensions/pg-extensions`, `.../btree_gist`, `.../introduction/plans`, `.../connect/connection-pooling`) | Extension table row `btree_gist`: PG14 1.6, PG15 1.7, PG16 1.7, PG17 1.7, PG18 1.8 (no notes). The extension's own page gives `CREATE EXTENSION IF NOT EXISTS btree_gist;` and an `EXCLUDE USING GIST (room_id WITH =, booking_period WITH &&)` example that blocks overlapping bookings. | Plans page (last updated 2026-11-12): Free plan `$0/month`; 1 GB storage per project; 100 CU-hours per project; compute suspends after 5 minutes idle (cannot be disabled); 5 GB public network transfer per project; community support. The page does not say whether a payment card is required. | **Selected**, verification pending |
| Render Postgres (`render.com/docs/postgresql-extensions`, `.../free`) | Listed for PostgreSQL 13 and later (no version column; no notes). | Free database "expires 30 days after creation", deleted after a 14-day grace period; no backups on the free tier. | Not selected: the expiry is unsuitable for an assessment review window of unknown length. Paid tiers not evaluated. |
| Heroku Postgres (`devcenter.heroku.com/...extensions...`) | Listed (`create extension btree_gist`) and shown in the supported-extension output for Essential, Standard-and-higher and Advanced. | No free option evidenced; pricing not checked. | Not selected. |
| Supabase (`supabase.com/docs/guides/database/extensions`, `.../btree_gist`) | **Not evidenced**: the pages read say "over 50 extensions" and describe enabling, but do not list `btree_gist`. | Not read. | Not selected: no evidence. |
| Railway (`docs.railway.com/guides/postgresql`) | **Not evidenced**: the page says default templates will not add extensions and does not mention `btree_gist`. | No free tier or trial evidenced; the TCP proxy is billed for egress. | Not selected: no evidence. |
| Amazon RDS (`docs.aws.amazon.com/.../postgresql-extensions.html`) | Listed for PostgreSQL 15–19 in the part of the page that could be read (version 14 not visible). The page does not say which role may create it. | Not evaluated. | Not selected: more operational weight than a 10,000-row demo needs; no free tier evaluated. |

**Why Neon, and what it does not prove.** Of the previously evaluated candidates, it supplied sufficient evidence combining documented `btree_gist` support for supported PostgreSQL majors with a documented $0 plan and no listed expiry. It does **not** show that the role the application's migration will use may run `CREATE EXTENSION` (the pages read do not say), that the exclusion constraint works on the hosted engine, or how the free plan behaves after idle.

**Known limitations and deployment implications.**
- **Connection.** Neon's pooler runs PgBouncer in transaction mode and the docs recommend a **direct** connection for schema migrations; pooled connections do not support session-level features such as session advisory locks. The application keeps one **direct (non-pooled)** connection string for migrations and runtime to simplify this small deployment. Transaction pooling does not inherently prevent transaction-scoped `SELECT ... FOR UPDATE`: PostgreSQL holds row locks until transaction end. Session advisory locks and transaction row locks are distinct; no pooling incompatibility is claimed. The connection string is a secret: environment variable only, never committed.
- **Role privilege.** If the migration role cannot create the extension, enable it once as the project owner role; `enable_extension "btree_gist"` is `IF NOT EXISTS`, so the Phase 3 migration then does nothing.
- **Free plan behaviour.** Compute suspends after 5 minutes idle; the pages read give no cold-start latency, so it is unmeasured. When compute hours or transfer run out the compute suspends (connections fail with SQLSTATE `53000`) until the next period; the page says limits do not delete data. Storage is capped at 1 GB per project; the 10,000-row dataset is expected to be far smaller but this is **unmeasured**.
- **Seed and migrations.** `db:migrate` and the one-off seed can run from the owner's machine against the direct connection string (or from the application host). Transfer from the owner's machine counts toward the 5 GB public transfer allowance. Running them from the application host depends on DR-22.
- **Application host.** Neon hosts only the database. The application host, region (keep it close to the database) and production CORS are DR-22.
- **PostgreSQL major.** postgresql.org lists 14.25 as the final release of PostgreSQL 14 (end of life 12 November 2026); 15 ends 11 November 2027, 16 on 9 November 2028, 17 on 8 November 2029 and 18 on 14 November 2030. The spike ran on 14.25. Neon lists `btree_gist` for 14–18; choose **17** (or 18) for the hosted database and run the Phase 3 specs on the same major locally (only PostgreSQL 14 is installed locally today).
- **Rails guide rechecked by Codex.** [Official Rails guide](https://neon.com/docs/guides/ruby-on-rails) is now accessible: it documents PostgreSQL URLs with TLS and Rails integration. This repository uses exported environment variables, so its optional dotenv installation is not adopted; use the explicit hosted database name rather than creating local-environment databases on the host.
- **Plan terms can change.** Re-check the plan limits and the card requirement when the project is created.

### 12.5 Hosted verification procedure (owner; pending)
Under separate provisioning authorization, create a throwaway Neon project (Free plan, PostgreSQL 17), using the same role and the **direct** connection string the application will use. Run the following in one SQL-editor session or `psql`; do not commit the connection string.

```sql
SELECT version();
CREATE EXTENSION IF NOT EXISTS btree_gist;
SELECT extname, extversion FROM pg_extension WHERE extname = 'btree_gist';
-- Temporary table is session-local and disappears on disconnect.
CREATE TEMP TABLE gist_probe (
  employee_id bigint NOT NULL, effective_from timestamptz NOT NULL, effective_to timestamptz,
  CHECK (effective_to IS NULL OR effective_to > effective_from),
  CONSTRAINT gist_probe_no_overlap
    EXCLUDE USING gist (employee_id WITH =, tstzrange(effective_from, effective_to, '[)') WITH &&));
INSERT INTO gist_probe VALUES (1, '2026-01-01T00:00:00Z', '2026-06-01T00:00:00Z');
INSERT INTO gist_probe VALUES (1, '2026-06-01T00:00:00Z', NULL); -- adjacent: succeeds
DO $$
BEGIN
  BEGIN
    INSERT INTO gist_probe VALUES (1, '2026-03-01T00:00:00Z', '2026-09-01T00:00:00Z');
    RAISE EXCEPTION 'FAIL: overlap accepted';
  EXCEPTION WHEN exclusion_violation THEN
    RAISE NOTICE 'PASS: overlap rejected, SQLSTATE 23P01';
  END;
END $$;
DROP TABLE gist_probe;
```

Then, with the connection string exported as `DATABASE_URL` for that shell only, run `cd backend && bin/rails runner 'puts ActiveRecord::Base.connection.select_value("select version()")'` to confirm the Rails `pg` driver connects (TLS included). **Pass criteria:** the extension is created by the application's role (or by the owner role, noted), the adjacent insert succeeds, the overlapping insert fails with `23P01`, and Rails connects. Record the `version()` string, the `btree_gist` version and the outcomes under this heading; only then tick the DR-20 box in §11. A failure means DR-20 stays open and the options are another provider or the weaker fallback in `domain-decisions.md` §6.2, which needs its own explicit approval.


### 12.6 Codex evidence recheck (17 November 2026)

The existing Neon Free selection is preserved. Official [extension versions](https://neon.com/docs/extensions/pg-extensions) and [btree_gist usage](https://neon.com/docs/extensions/btree_gist) still document PostgreSQL 17/18 support, extension creation and the scalar-plus-range exclusion pattern. The [role guide](https://neon.com/docs/manage/roles) distinguishes administrator roles created via Console/API from minimally privileged SQL roles. Extension-enabling instructions support feasibility; the exact migration role must still be tested. The [Rails guide](https://neon.com/docs/guides/ruby-on-rails) and [connection guidance](https://neon.com/docs/connect/connection-pooling) support TLS PostgreSQL URLs and direct migration connections. The [plans page](https://neon.com/docs/introduction/plans) still lists the Free limits recorded above; recheck limits and card requirements at provisioning. Other-provider rows in §12.4 are preserved historical evaluation, not newly verified comparative claims. Neon is sufficient; no provider change is necessary.

Inference: existing Rails migrations and the one-off deterministic seed can run through the standard `pg` connection; this is not a hosted execution result. Export the explicit database URL with TLS through the server environment or host secret settings, keep it out of frontend variables and logs, and keep the API pool within provider limits. No dotenv or new dependency is needed. Before release, verify migrations, schema load/prepare on disposable databases, one-off seed invariants/determinism and TLS connection under the chosen role. DR-22 still determines the application host and release-command integration.

No hosted runtime check occurred. The historical local spike is not independently reproduced: local PostgreSQL access is unavailable in this sandbox and isolated `initdb` failed at shared-memory allocation. Current checks and their limits are in `audit-report.md`; the G1 checklist in `implementation-plan.md` supersedes earlier readiness claims. No gate was moved or waived.

**Current audit scope:** changes are documentation only. Pre-existing Phase 3–7 backend artifacts were preserved; their authorship is not established by the staged/unstaged split. The original G0/G1 sign-off requirements remain, and the owner must review that existing implementation separately before further feature work.
