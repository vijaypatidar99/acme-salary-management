# Architecture Review and Decision Register

**Status:** Draft for owner approval. **The architecture is not finalized.** Nothing here has been implemented or measured.
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
| **Technology choice** (project/owner direction; **not** assessment requirements) | Rails API mode, PostgreSQL, RSpec, React + TypeScript + Vite, Vitest + React Testing Library, TanStack Query, Tailwind CSS, one monorepo. Versions are pinned at bootstrap from what is current then; none are chosen here |
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

Every unresolved decision has the same fields. **All are [APPROVAL] — pending.** Recommended defaults are used in the other documents only as clearly labelled working defaults. Other documents reference these IDs instead of keeping their own lists.

### 3.1 Approval gates (what must be resolved before each phase starts)

| Gate | Must be approved before | Decisions |
|------|-------------------------|-----------|
| **G0** | Phase 2 starts | Explicit owner approval of the six documents and this register; DR-24 |
| **G1** | Phase 3 starts | DR-01, DR-03, DR-05, DR-09, DR-11, DR-12, DR-14, DR-20, DR-21 |
| **G2** | Phase 4 starts | DR-04, DR-06, DR-07, DR-10 (plus G1) |
| **G3** | Phase 5 starts | DR-02, DR-18, DR-19, DR-23 (write-endpoint rate-limiting decision) |
| **G4** | Phase 6 / 7 start | DR-17 (Phase 6, with DR-07 from G2); DR-08, DR-13, DR-15, DR-16 (Phase 7) |
| **G5** | Phase 11 starts | DR-22 (hosting, topology and CORS handling) |

**No gate has been passed.** A gate is passed only when the owner explicitly approves its decisions and this register is updated; nothing in the repository counts as that evidence.

DR-21 is *decided* after the Phase 2 capability spike (see DR-20/21) but must be resolved before Phase 3 migrations are written.

### 3.2 Blockers

**DR-01 — Effective-date type** `[APPROVAL]`
- Question: are salary effective values timestamps or dates?
- Recommended default: `timestamptz`, server-set at revision time ("effective immediately"), displayed in UTC.
- Reason: a mistaken revision can be superseded immediately even though retroactive corrections are out of scope; no calendar-day/time-zone ambiguity; exact interval arithmetic.
- Trade-off: HR convention is usually a date. Dates force a one-revision-per-day rule (the second revision would produce an empty interval) and a defined time zone for "today".
- Blocks: Phase 3 (column types), 4, 5, 9.

**DR-02 — Public-demo write protection** `[APPROVAL]`
- Question: how are salary-revision writes protected on the public demo?
- Recommended default: shared write passphrase in `Authorization: Bearer …`, kept in React in-memory state only, compared in constant time against a server secret, fail closed (403) when unset. Reads open because all data is synthetic.
- Reason: smallest real protection for the one mutating endpoint without introducing user accounts (excluded by the brief); no secret in the frontend bundle.
- Trade-off: no per-user identity or audit attribution; the passphrase is lost when the page is reloaded or the tab is closed (re-entry), but is **not** cleared by in-app route changes; brute-force resistance depends on passphrase strength and any throttling (DR-23). Alternatives (Basic auth, session login, open writes with reset, read-only) rejected in `architecture.md` §9.2.
- Blocks: Phase 5 (endpoint), 8, 9, 11.

**DR-03 — Employment statuses and the active-payroll population** `[APPROVAL]`
- Question: which statuses exist, which count toward active payroll totals, which may be revised?
- Recommended default: `active`, `on_leave`, `terminated`; only `active` counts toward payroll totals (literal reading of the brief); `active` and `on_leave` may be revised; `terminated` may not.
- Reason: smallest set satisfying "employment statuses" and "active employees".
- Trade-off: `on_leave` staff are normally still paid, so excluding them from totals is debatable; the simplest alternative drops `on_leave` (two statuses). The brief does not define "active".
- Blocks: Phase 3 (CHECK), 4 (eligibility), 5 (API eligibility/filters), 6, 7, 9.

**DR-04 — Mandatory `expected_current_salary_record_id`** `[APPROVAL]`
- Question: must a revision request carry the id of the current record the user saw?
- Recommended default: mandatory; mismatch → `409 stale_salary_record`.
- Reason: the row lock serializes writers but does not stop a lost update by a user working from a stale page; also makes double-submit harmless.
- Trade-off: one more field for the client to carry; optional would be simpler but permits silent overwrites. If resolved as optional, a missing token skips the check (`domain-decisions.md` §7) and the `400` for a missing token disappears.
- Blocks: Phase 4, 5, 9.

### 3.3 Important domain decisions

**DR-05 — FX-rate snapshot semantics** `[APPROVAL]`
- Question: how is "the conversion rate used" retained?
- Recommended default: copy the rate value onto each salary record (`fx_rate`); `exchange_rates` is only the lookup source. Rate lookup = row with the greatest `effective_on` ≤ the UTC date of the revision's effective timestamp.
- Reason: reproducible and independent of later edits to the rate table; no extra join.
- Trade-off: denormalized snapshot; totals use each record's own rate, so if rates ever varied over time, org totals would mix rate dates (harmless with one fixed rate per currency). Alternative: FK to an immutable rate row.
- Blocks: Phase 3, 4 (lookup and snapshot), 5 (responses/CSV), 6 (seeded snapshots).

**DR-06 — Per-employee rounding policy** `[APPROVAL]`
- Question: where is rounding applied?
- Recommended default: annualize → convert once → round once per employee to 2 dp (half away from zero); totals/averages/medians aggregate the rounded values; averages and medians rounded at output.
- Reason: dashboard totals reconcile exactly to the CSV rows.
- Trade-off: slightly less precise than aggregating unrounded values and rounding last.
- Blocks: Phase 4, 7.

**DR-07 — Currency independent of employee country** `[APPROVAL]`
- Recommended default: salary currency is chosen per record; not derived from or validated against country.
- Reason: the brief treats multiple currencies and countries as separate; supports expatriates/contractors and shared currencies (EUR).
- Trade-off: data-entry mismatches (e.g. an Indian employee paid in USD) are accepted silently.
- Blocks: Phase 4, 6.

**DR-08 — Low-sample threshold** `[APPROVAL]`
- Recommended default: a group is `low_sample` when active headcount < 10 (named constant).
- Reason: the brief requires group size to be visible so small samples aren't misleading, but gives no number.
- Trade-off: arbitrary; too high flags many legitimate groups, too low misleads.
- Blocks: Phase 7 (including the `low_sample_threshold` field added to reference data) and Phase 9 (UI flag).

**DR-09 — Terminated employees and salary history** `[APPROVAL]`
- Recommended default: a terminated employee's last salary record stays open; they are excluded from totals; further revisions are rejected; `terminated_on` is set iff status is `terminated`.
- Reason: preserves "exactly one open record per employee"; needs no termination workflow (lifecycle management is excluded).
- Trade-off: the open record means "last salary held", not "currently paid". Alternative (close at `terminated_on`) leaves employees without a current salary.
- Blocks: Phase 3, 4.

**DR-10 — No-op salary revisions** `[APPROVAL]`
- Recommended default: reject when amount, currency and frequency equal the current record (`422 no_change`).
- Reason: a reason-only change is not a salary revision; avoids noise in history.
- Trade-off: HR cannot log "reviewed, no change".
- Blocks: Phase 4.

**DR-11 — Salary amount upper bound** `[APPROVAL]`
- Question: what is the exact maximum accepted `amount`?
- Recommended default for discussion: 1,000,000,000.00 in local-currency units per pay period, as a sanity guard rather than business policy.
- Reason: rejects typos; well inside `numeric(14,2)` capacity (999,999,999,999.99).
- Trade-off: a uniform number is crude across currencies with very different scales. **The bound is not chosen until approved**; documents refer to "the approved bound (DR-11)". Independent of the bound, values exceeding column capacity are rejected with `422 validation_failed` before reaching the database.
- Blocks: Phase 3 (if a CHECK is used), 4, 5.

**DR-12 — Revision reason** `[APPROVAL]`
- Recommended default: required free text, trimmed, 1–255 characters.
- Reason: the brief requires preserving "its reason"; nothing reports by reason, so no controlled vocabulary.
- Trade-off: not analysable; typos/inconsistency.
- Blocks: Phase 3, 4.

**DR-13 — Country and department grouping behaviour** `[APPROVAL]`
- Recommended default: analytics group by the employee's current country/department against the current salary; no history of country/department; no as-of group analytics; a country change does not alter salary currency.
- Reason: no requirement for history; nothing is stored redundantly.
- Trade-off: past reports cannot be reproduced after a transfer.
- Blocks: Phase 7.

**DR-14 — `reference_data` endpoint and `currencies` table** `[APPROVAL]`
- Recommended default: keep both (optional enhancements).
- Reason: FK integrity for salary/rate currency; avoids hard-coding option lists in the frontend. `has_rate` is defined precisely in `api-contracts.md`.
- Trade-off: one more table and endpoint than the minimum. Alternative: a CHECK/constant list and constants in the SPA.
- Blocks: Phase 3, 5, 8, 9.

**DR-15 — Median definition** `[APPROVAL]`
- Recommended default: statistical median computed exactly in `numeric`: middle value for odd n; arithmetic mean of the two middle values for even n; rounded to 2 dp at output (half away from zero). Same definition for organization, country, department.
- Reason: `percentile_cont` coerces to `double precision`, which the money rules forbid.
- Trade-off: needs a ranking query (window functions) rather than a single aggregate call.
- Blocks: Phase 7.

**DR-16 — Analytics scope additions** `[APPROVAL]`
- Recommended default: optional `country`, `department`, `job_level` filters; `local_totals` (per currency) on country rows only; `status_counts`.
- Reason: gives meaning to "selected groups" and "local-currency amounts where relevant", both undefined in the brief.
- Trade-off: extra query/payload complexity for thinly specified requirements; could be cut to by-country/by-department only.
- Blocks: Phase 7, 9.

**DR-17 — Seed dataset parameters** `[APPROVAL]`
- Recommended default: curated in-repo name lists (no Faker), fixed RNG seed, fixed anchor date ≤ deployment date, illustrative fixed rates, status proportions fixed in code, at least one group below the low-sample threshold, countries sharing a currency.
- Reason: byte-identical reruns; no dependency.
- Trade-off: less realistic names than Faker.
- Blocks: Phase 6.

**DR-18 — Presentation and addressing conventions** `[APPROVAL]`
- Recommended default: employees addressed by numeric `id` in URLs; timestamps displayed in UTC; page size default 25, max 100; sort allow-list as in `api-contracts.md`.
- Trade-off: sequential ids are enumerable (irrelevant for synthetic data); UTC display is unfamiliar to some users.
- Blocks: Phase 5, 8, 9.

**DR-19 — Unpaginated salary history** `[APPROVAL]`
- Recommended default: return the full history inside `GET /employees/:id` as a conscious MVP trade-off. No maximum number of revisions is guaranteed.
- Reason: smallest API; seeded histories are short.
- Trade-off: payload grows linearly with revisions. Revisit (e.g. a paginated history endpoint) if Phase 10 measurement with a long-history fixture shows a problem.
- Blocks: Phase 5.

### 3.4 Infrastructure decisions

**DR-20 — PostgreSQL provider and `btree_gist` availability** `[APPROVAL]`
- Question: which PostgreSQL hosting option will be used, and does it support `CREATE EXTENSION btree_gist`? Alternatively, is the weaker fallback approved?
- Recommended default: the owner selects the intended database provider **before Phase 3** and verifies the extension on it (a throwaway database is enough); the exclusion constraint stays in the design. Local development also needs the extension (checked in the Phase 2 spike).
- Reason: Phase 3 builds the constraint; discovering at Phase 11 that the host lacks it would force rework.
- Fallback (needs its own explicit approval): partial unique index + employee row lock + application overlap validation. This gives a **weaker guarantee**: bugs or manual SQL could create overlapping closed intervals, which the database would no longer reject.
- Trade-off: choosing the database provider early constrains the later application-hosting choice (DR-22) only mildly.
- Blocks: Phase 3 (gate G1).

**DR-21 — `schema.rb` versus `structure.sql`** `[APPROVAL]`
- Recommended default: `schema.rb`, **if** the Phase 2 capability spike shows that the pinned Rails version dumps and reloads the extension, CHECK constraints, partial unique index and exclusion constraint faithfully. Otherwise `structure.sql`.
- Reason: `schema.rb` is simpler to read and review; correctness of the dump matters more than convenience.
- Trade-off: `structure.sql` is more complete but noisier and needs matching `pg_dump` versions.
- Blocks: Phase 3.

**DR-22 — Hosting provider, deployment topology and CORS handling** `[APPROVAL]`
- Question: where are the SPA, API and database hosted, how are they arranged, and — if the SPA and API are on different origins — how is CORS configured (including whether the `rack-cors` gem may be added)?
- Recommended default: two deployables (static SPA + Rails API) and one managed PostgreSQL, unless the chosen provider makes same-origin serving simpler. CORS, if needed, is restricted to an explicit allow-list of configured origins (never a wildcard) and must permit the `Authorization` header. Prefer same-origin serving or a small hand-written Rack middleware before adding `rack-cors`; adding the gem needs approval under this decision. The assessment specifies no provider.
- Reason: conventional, independent deploys. Same-origin avoids CORS entirely.
- Trade-off: cross-origin needs an explicit allow-list, preflight for the `Authorization` header and possibly a dependency.
- Blocks: Phase 11 (gate G5); decide before Phase 8 if possible because it fixes the API base URL and CORS needs.

**DR-23 — Write-endpoint rate limiting** `[APPROVAL]`
- Question: is throttling of the write endpoint required for the public demo, and if so by what means (platform-level limits, or the `rack-attack` gem)?
- Recommended default: add nothing now. Use platform-level throttling if the chosen provider offers it; otherwise accept the risk for a synthetic demo with a long random passphrase. Treat `rack-attack` as opt-in and approve it here before it is added.
- Reason: avoid unapproved dependencies; risk is bounded by synthetic data.
- Trade-off: without throttling the passphrase is brute-forceable.
- Blocks: Phase 5 (gate G3); Phase 11 verification applies only if throttling is approved.

**DR-24 — Baseline bootstrap dependencies** `[APPROVAL]`
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
| R-3 | Hosting database may lack `btree_gist` | DR-20 resolved before Phase 3, not Phase 11 |
| R-4 | `schema.rb` may not faithfully dump all constraints | Phase 2 spike; DR-21 |
| R-5 | Shared passphrase: no identity/audit, brute-forceable without throttling | Accepted for synthetic demo; fail closed; strong passphrase; DR-23 |
| R-6 | Open reads on a salary application | Acceptable only because data is synthetic; a demo decision, not a pattern |
| R-7 | Public CSV export (10,000 rows) can be abused | Batched streaming; platform limits; unmeasured |
| R-8 | Microsecond truncation: Ruby nanoseconds vs PostgreSQL microseconds could make `effective_to ≠ next.effective_from` | Truncate once, reuse the same value; test boundary equality (Phase 4) |
| R-9 | Median coercion to `double precision` if `percentile_cont` is used | Excluded by design (DR-15); regression test with a large-magnitude half-cent case |
| R-10 | Group medians in USD across countries are easily misread | Headcount always shown; `low_sample`; caveat copy; no "inequity", "attrition", compa-ratio wording |
| R-11 | Country/department changes have no history | DR-13; no as-of group analytics |
| R-12 | `ILIKE '%term%'` performance unmeasured | Measure in Phase 10; `pg_trgm` needs approval |
| R-13 | Terminated/on-leave employees exist only via seed (no workflow) | Acceptable; rules tested through fixtures |
| R-14 | Clock skew between app instances could trigger `revision_conflict` | Unreachable on one instance; the clock is read after the row lock so lock order matches time order |
| R-15 | Natural-key primary keys (`code`) differ slightly from Rails convention | Supported; confirm in Phase 3 |
| R-16 | Frontend types drift from the API contract | Contract cross-check in Phase 10 |
| R-17 | Fixed illustrative FX rates mistaken for real rates | Labelled in UI and API notes |
| R-18 | Unpaginated salary history grows with revisions (DR-19) | Conscious trade-off; measure with a long-history fixture in Phase 10 |
| R-19 | Passphrase leaks via logs/proxies (header logging) | Never log `Authorization`; verify in Phase 11 |
| R-20 | The decimal-string rules reject some inputs users might type (commas, spaces) | UI normalizes display input before sending; server stays strict |
| R-21 | CSV formula injection: RFC 4180 quoting alone does not prevent it, and prefixing is a mitigation, not a guarantee for every spreadsheet application | Deterministic sanitization policy and required test table in `api-contracts.md` §5; exported files treated as untrusted by consumers |
| R-22 | In-memory passphrase is lost on reload/tab close but persists across in-app navigation | Documented accurately (`architecture.md` §9.3); discarded on `401`; short re-entry friction accepted |

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
| U-1 | The owner's review asks that the timestamp-based revision flow and the per-employee rounding rule be applied consistently, while also listing DR-01 and DR-06 as unresolved | Both written as **working defaults** and labelled `[APPROVAL]`; confirm or replace |
| U-2 | The brief says totals include "active employees" without defining "active"; status set is not specified | DR-03 |
| U-3 | The brief asks for local-currency amounts "where relevant" and comparisons "for selected groups" without defining either | DR-16 |
| U-4 | The assessment does not name a hosting provider, yet Phase 3 requires `btree_gist` | Owner must pick the database provider before Phase 3 (DR-20) |
| U-5 | Export includes every status matching the filters, while dashboard totals are active-only | Behaviour kept; UI note; reconciliation only with `status=active`, matching country/department scope, no `job_level` or `q` |

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

## 8. Self-critique

**Tensions in the design**
1. "Prevent overlapping salary periods" with immediate-only revisions means overlap can arise only from concurrency or bugs; the constraint is defence in depth.
2. Per-record rate snapshots can mix rate dates in totals if rates ever vary (DR-05).
3. The exclusion constraint subsumes the partial unique index; the index is kept for the current-salary lookup and a clearer error. Neither guarantees an open record exists.
4. An exact median via window functions costs more SQL than one aggregate call; acceptable at 10,000 rows, to be measured.

**Complexity that could be cut:** `on_leave` (DR-03), `local_totals` and the `job_level` analytics filter (DR-16), `reference_data` and `currencies` (DR-14), the mandatory token (DR-04, kept for real lost-update risk), the identity `USD→USD` rate row.

**Missing business rules (not invented):** salary ranges per level/country; approval workflows; rehires/transfers/multiple jobs; retention/audit requirements; currencies with ≠ 2 decimals; response-time targets (none specified; none claimed).

**Checked and not claimed:** the partial unique index is not described as preventing all historical overlaps; peer medians are not compa-ratios; outliers are not evidence of inequity or attrition; no performance numbers, stakeholder answers or assessment requirements are invented; `percentile_cont` behaviour is stated from PostgreSQL's documented signature and must be confirmed by a test on the pinned PostgreSQL version in Phase 7 (not executed here).

## 9. Proposed changes to `docs/requirements.md` (NOT applied; need explicit approval)
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

Architecture may be treated as approved only after every box is ticked. Nothing below is approved yet.

**G0 — before Phase 2**
- [ ] Reviewed the six documents and this register; accept scope and exclusions.
- [ ] DR-24 baseline dependency list.
- [ ] Explicit go-ahead for Phase 2 (bootstrap only).

**G1 — before Phase 3**
- [ ] DR-01 timestamp vs date effectivity.
- [ ] DR-03 statuses, active-payroll population, revision eligibility.
- [ ] DR-05 FX snapshot semantics.
- [ ] DR-09 terminated-employee handling.
- [ ] DR-11 salary amount upper bound (exact number).
- [ ] DR-12 required free-text reason.
- [ ] DR-14 `currencies` table / `reference_data` endpoint (keep or cut).
- [ ] DR-20 database provider chosen and `btree_gist` verified (or the weaker fallback explicitly approved).
- [ ] DR-21 `schema.rb` vs `structure.sql` (after the Phase 2 spike).

**G2 — before Phase 4**
- [ ] DR-04 mandatory token. · [ ] DR-06 rounding policy. · [ ] DR-07 currency vs country. · [ ] DR-10 no-op rejection.

**G3 — before Phase 5**
- [ ] DR-02 write protection. · [ ] DR-18 conventions. · [ ] DR-19 unpaginated history. · [ ] DR-23 write-endpoint rate limiting.

**G4 — before Phases 6–7**
- [ ] DR-17 seed parameters. · [ ] DR-08 low-sample threshold. · [ ] DR-13 grouping behaviour. · [ ] DR-15 median definition. · [ ] DR-16 analytics scope.

**G5 — before Phase 11**
- [ ] DR-22 hosting, topology and CORS handling (including whether `rack-cors` may be added).

**Other**
- [ ] Requirements changes in §9: accept, reject or defer each.
- [ ] Decision on whether the assessment PDF may be committed (default: it is not).
