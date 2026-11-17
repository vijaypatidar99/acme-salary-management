# Copilot Instructions — ACME Salary Management

## Product
Web app for an ACME **HR Manager** to find employee compensation records, revise base salaries without losing history, and understand how base pay is distributed across 10,000 synthetic employees in multiple countries and currencies.

## Source-of-truth hierarchy (higher wins; read the relevant documents before implementing anything)
1. The original Incubyte assessment (held by the owner; not in the repo — do not add it to a public repo without owner approval).
2. `docs/requirements.md` — product goal, scope, workflows, exclusions. Never edit without explicit owner approval; propose changes separately.
3. `docs/domain-decisions.md` — domain rules.
4. `docs/architecture.md` — technical architecture.
5. `docs/api-contracts.md` — API behaviour.
6. `docs/implementation-plan.md` — phase order, approval gates and acceptance criteria.
7. `docs/architecture-review.md` — **decision register**, risks, outstanding approvals. It records decisions; it is not a source of business rules.
8. This file — implementation guardrails only; it cannot override any document above.

If two documents disagree, the higher one wins. Report the conflict and update the lower document; do not silently pick. Do not invent business rules: if a rule is missing or ambiguous, ask the owner. Do not silently change requirements or scope.

## Approved vs pending
- **Check the decision register (`docs/architecture-review.md` §3) before implementing anything.** A decision marked `[APPROVAL]` is **proposed, not approved**, even if another document states the default in the present tense. Do not implement code that depends on a pending decision; ask the owner.
- Approved baseline: assessment requirements; `requirements.md`; half-open salary intervals; the revision order in `docs/domain-decisions.md` §7 with one effective timestamp read once after the row lock; money types below; an exact `numeric` median that never uses `percentile_cont` or a float cast (DR-15 definition now decided under delegation); pagination/CSV/`status_counts`/empty-group behaviour as written in `api-contracts.md`; and the decisions approved on 17 November 2026 — UTC `timestamptz` effectivity with one microsecond-normalised timestamp per revision (DR-01); statuses `active`/`on_leave`/`terminated`, `on_leave` revisable, `terminated` not, analytics over `active` only (DR-03); mandatory `expected_current_salary_record_id` (DR-04); entered-amount maximum `1000000000.00` in the salary's own currency and frequency, validated in the application (DR-11); the `btree_gist` exclusion-constraint + partial-unique-index design (DR-20, hosted-provider verification still open); `schema.rb` with `varchar(2)`/`varchar(3)` codes and CHECKs, not `structure.sql` (DR-21); the DR-24 dependency baseline (no `pagy`, `faker` or `lucide-react`; `rack-cors` for local development only). Approved under delegated authority on 17 November 2026 (owner review pending): each salary record stores the rate used as `fx_rate` (DR-05); a terminated employee's last record stays open and `terminated_on` is set iff status is `terminated` (DR-09); `reason` is required, trimmed, 1–255 characters (DR-12); the `currencies` table and `GET /api/v1/reference_data` are in scope (DR-14). Neon (Free plan, direct connection) is the selected database provider (DR-20); `btree_gist` is **not yet verified on it**, so do not assume hosted support.
- The remaining low-risk MVP defaults (DR-02, DR-06–DR-08, DR-10, DR-13, DR-15–DR-19 and DR-23) were decided under the current owner's delegation on 17 November 2026; see the register for rationale and accepted trade-offs. They await owner gate review, not repeated technical selection. DR-22 (application hosting/topology/production CORS) and DR-20 hosted runtime verification remain unresolved. G1 is OPEN; delegated decisions do not constitute owner gate sign-off.
- Existing backend code beyond the scaffold was present when this documentation audit began. Preserve it; its presence is not approval or phase acceptance. Do not implement or extend Phase 3 or later until the owner reviews the audit and the original gate prerequisites pass. See `docs/audit-report.md`.

## Technology choices (project choices, not assessment requirements)
Rails API mode, PostgreSQL, RSpec; React + TypeScript + Vite, TanStack Query, Tailwind, Vitest + React Testing Library; one monorepo (`backend/`, `frontend/`, `docs/`, `.github/`). Pin versions at bootstrap from what is actually current; do not guess.

## Scope
- Work only on the **current phase** of `docs/implementation-plan.md`, and only if its blocking decisions are approved. Do not start the next phase.
- In scope: directory (search/filter/paginate), employee detail with history, salary revision, compensation analytics (USD), filtered CSV export, deterministic 10,000-employee seed.
- Out of scope: payroll, tax, payslips, bonuses, equity, benefits, allowances, hourly/variable pay, bulk import, live FX, future-dated/retroactive changes, employee CRUD/lifecycle, registration/RBAC/SSO, attrition prediction, pay-equity conclusions.
- Do not add features, endpoints, dependencies, infrastructure, CI/deployment config or broad refactors that are not in the current phase. Ask before adding any gem or npm package not approved in the register.

## Money and salary rules
- **Never use `Float`/`double precision` for money** — not in Ruby, SQL (including intermediate casts), JSON or TypeScript. Ruby `BigDecimal`; PostgreSQL `numeric`; API money values are decimal **strings**.
- The frontend formats money for display only: no sums, conversions, comparisons or aggregation.
- Never add amounts in different currencies. Currency and country are separate concepts. A missing exchange rate is a validation error, never a default of 1.
- Follow the calculation order in `docs/domain-decisions.md` §4 (annualize first, convert once, round once per employee, aggregate the rounded values, round average and median at output); DR-06 is decided under delegation and awaits owner gate review. Keep SQL and Ruby formulas identical and covered by parity tests.
- Salary history is append-only: never edit amount/currency/frequency/reason of an existing record. A revision runs in one transaction that locks the employee row, re-reads the current record after the lock, reads the clock once, and uses that one timestamp for the FX lookup date, closing the previous record and creating the new one.
- Do not claim a database constraint guarantees more than it does: the partial unique index prevents only multiple open records; the exclusion constraint prevents overlapping intervals; "at least one open record" is established by service, seed and verification.

## Engineering expectations
- Follow Rails conventions and keep changes small, focused and easy to review. No unnecessary abstractions, patterns or dependencies; add an abstraction only when the current phase needs it.
- Thin controllers; business rules in models/services/query objects; one definition of each formula.
- Enforce integrity in the database **and** validate in the application.
- Server-side pagination, filtering and sorting. **Parameterize all SQL** (bind variables, never interpolate user input) and **allow-list sort fields**. Prevent N+1 queries.
- Prefer simple indexed PostgreSQL; no Redis, Elasticsearch, background jobs for reads, or caching without a measured need.
- Match the surrounding code's style, naming and comment density; comment the *why*.

## Security
- No secrets in the frontend bundle, `VITE_*` variables, URLs/query parameters, logs or committed files. Never log the write passphrase or the `Authorization` header. 500 responses never expose exception details.
- Write passphrase (DR-02, approved under delegation): React in-memory state only (lost on reload/tab close, not on in-app navigation), HTTPS only, constant-time server comparison, fail closed (`403`) when unconfigured. CORS, if needed, only for configured origins.
- CSV exports sanitize text cells against formula injection per `docs/api-contracts.md` §5; quoting alone is not a defence.
- Data is synthetic only; never add real personal data.

## Testing
- Meaningful, fast, deterministic tests (fixed clocks, no network, seeded randomness).
- **Tests are required** for every business rule and every database constraint, including negative cases and boundary cases (half-open intervals, rounding, median of 0/1/odd/even rows, missing rate, stale token).
- Test behaviour, not implementation details.

## Git and honesty
- Small, incremental commits. **Do not commit or push without explicit owner permission.**
- State assumptions and the document they come from; mark anything unapproved as an assumption.
- **Never claim a command ran, a test passed, a benchmark was measured or something was deployed unless you actually did it and saw the output.** Report failures verbatim.
- Do not invent performance numbers, stakeholder answers or assessment requirements. Unspecified by the assessment: deadline, hosting provider, video duration.
- Describe peer comparisons as comparisons only: not compa-ratio (no salary bands), not evidence of pay inequity or attrition risk.
