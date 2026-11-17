# Domain Decisions

**Precedence:** rank 3 in the hierarchy defined in `architecture-review.md` §1. This document refines `docs/requirements.md` and never overrides it.
**Status legend**
- **Approved** — comes from the assessment, `requirements.md`, or an explicit owner instruction (source stated).
- **Proposed — DR-nn `[APPROVAL]`** — a working default awaiting owner approval. The register in `architecture-review.md` §3 holds the question, trade-off and blocked phase. Nothing marked this way may be treated as final, and dependent implementation must not start until it is approved.

Terminology: *reporting currency* = USD (agreed in the brief). *Local currency* = the currency a salary record is denominated in.

## 0. Approved baseline vs pending decisions

| Rule | Status |
|------|--------|
| Base salary only; monthly and annual frequencies | Approved (brief) |
| Annualize monthly ×12; annual unchanged | Approved (brief) |
| USD reporting currency; fixed seeded illustrative rates; no live FX | Approved (brief) |
| Retain local currency and the conversion rate used | Approved (brief) |
| Never sum raw amounts of different currencies | Approved (brief) |
| Revisions are immediate; no future-dated or retroactive changes | Approved (brief) |
| History preserved; reject non-positive amounts; prevent overlapping periods | Approved (brief) |
| Totals include active employees, using annualized converted base salary | Approved (brief); *the meaning of "active"* is DR-03 |
| Group size shown beside average/median | Approved (brief) |
| Half-open intervals `[effective_from, effective_to)` | Approved (owner instruction) |
| One effective timestamp per revision, read after the lock, truncated once | Approved as a procedure (owner instruction); *timestamp vs date* is DR-01 |
| Money types and exact `numeric` median method (§4, §10) | Approved (owner instruction); rounding *policy* DR-06, median *definition* DR-15 |
| Synthetic data only; exactly 10,000 employees | Approved (brief) |
| Effective type (timestamp/date) | **DR-01** |
| Employment statuses; active payroll population; who may be revised | **DR-03** |
| `fx_rate` copied onto salary records | **DR-05** |
| Per-employee rounding | **DR-06** |
| Currency independent of country | **DR-07** |
| Mandatory stale-edit token | **DR-04** |
| No-op rejection | **DR-10** |
| Amount upper bound | **DR-11** |
| Required free-text reason | **DR-12** |
| Terminated employee handling | **DR-09** |
| Country/department grouping | **DR-13** |
| Low-sample threshold | **DR-08** |
| Median definition for even n | **DR-15** |
| Analytics scope additions | **DR-16** |
| Seed parameters | **DR-17** |

The sections below state each rule in the form used for design review; the status of each is the one in this table.

---

## 1. Salary basis
- Only **base salary** is modelled. No bonus, allowance, equity, benefits, hourly or variable pay.
- Frequencies: `monthly`, `annual`. Nothing else is accepted.
- A salary record holds one amount, one currency, one frequency. *(Approved)*

## 2. Annualization *(Approved)*
```
annual_local = amount × 12   if frequency = monthly
annual_local = amount        if frequency = annual
```
- 12 months per year; no 13th-month schemes.
- Stored amounts have 2 decimals and the multiplier is an integer, so `annual_local` is exact at 2 dp; no rounding at this step.
- `annual_local` is **computed, never stored**.

## 3. Currencies, countries and exchange rates

### 3.1 Currency vs country — Proposed, DR-07 `[APPROVAL]`
- A salary's currency is chosen on the record. It is neither derived from nor validated against the employee's country. Two countries can share a currency (e.g. Germany and France in EUR); an employee may be paid in another currency.
- Alternative (force currency = country default) breaks expatriate/contractor cases and conflates two concepts.

### 3.2 Rate representation *(shape: working design; values illustrative)*
- A rate row means **1 unit of `from_currency` = `rate` units of `to_currency`**, valid from `effective_on` (a date, inclusive) until a later row for the same pair supersedes it.
- Local → reporting: `reporting_amount = local_amount × rate(from = local, to = USD)`.
- Only `to_currency = USD` pairs are seeded/used in the MVP. The pair-plus-date shape costs one column and makes direction explicit.
- USD → USD has an identity row (`rate = 1`) so conversion has no special case; a CHECK requires `rate = 1` when `from = to`.
- Precision `numeric(18,8)`. Seeded rates are **illustrative planning rates, not market data**, fixed, no live feed.

| from | to | rate (illustrative placeholder) |
|------|----|---------------------------------|
| USD | USD | 1.00000000 |
| EUR | USD | 1.08000000 |
| GBP | USD | 1.27000000 |
| INR | USD | 0.01200000 |

### 3.3 Rate lookup and snapshot — Proposed, DR-05 `[APPROVAL]`
- **Lookup policy:** the rate row with the greatest `effective_on` ≤ **the UTC date derived from the revision's single effective timestamp** (§7). No second clock read.
- **No such rate → `422 missing_exchange_rate`**; nothing is written. Never default to 1; never skip conversion.
- The chosen rate value is copied onto the new record as `fx_rate`, so past reporting does not depend on the rate table staying unchanged.
- Seeded historical records snapshot the rate effective at their own `effective_from`; the seeded rate set starts at a floor date earlier than any seeded salary.
- Consequence to accept: totals use each record's own snapshot. With one fixed rate per currency this equals a single rate; if rates ever differ over time, org totals mix rate dates. A "revalue at date X" report would be future work.
- The reporting currency is a system constant; changing it would require re-snapshotting (out of scope).
- **`has_rate` (reference data)** means: a usable `currency → USD` rate exists, under the lookup policy above, for the **current UTC date** (USD always qualifies through its identity row). The server re-validates at submission because the date can differ from page load.
- The seed follows the same rules: each seeded record's `fx_rate` comes from the same lookup policy and each seeded `annual_reporting` is derived by the same formula (§4.2); the seed has no formula of its own, and the UI only displays values computed by the API.

## 4. Precision, rounding, and input format

### 4.1 Types *(Approved rule set; owner instruction)*
- Ruby: `BigDecimal`. PostgreSQL: `numeric`. JSON: decimal **strings**. Frontend: display formatting only; no money arithmetic, comparison or aggregation.
- Never use `Float` / `double precision` for money, including intermediate casts (this is why `percentile_cont` is excluded, §10.3).

| Item | Type / rule |
|------|-------------|
| Salary amount | `numeric(14,2)`, `> 0`; capacity 999,999,999,999.99 |
| FX rate | `numeric(18,8)`, `> 0` |
| Currency exponent | All supported currencies have 2 minor-unit decimals; zero/three-decimal currencies are not seeded |
| Rounding mode | Half away from zero: PostgreSQL `ROUND(numeric, 2)`; Ruby `BigDecimal#round(2, :half_up)`. Identical for the positive-only values used here |

### 4.2 Rounding policy — Proposed, DR-06 `[APPROVAL]`
Order of operations (working default):
1. `annual_local = amount × (12 | 1)` — exact.
2. `annual_reporting = ROUND(annual_local × fx_rate, 2)` — **annualize first, convert once, round once per employee**.
3. `SUM`, `AVG` and the median are computed over the **already-rounded** per-employee `annual_reporting`; average and median are rounded to 2 dp only at output.

Rationale: org totals equal the sum of the per-employee values shown in the UI and CSV. The alternative (aggregate unrounded, round last) is slightly more precise but not reproducible from visible rows.

| Case | Calculation | Result |
|------|-------------|--------|
| INR 250,000 monthly | ×12 = 3,000,000.00; × 0.012 | **36,000.00 USD** |
| EUR 3,333.33 monthly | 39,999.96; × 1.08 = 43,199.9568 | **43,199.96 USD** |
| GBP 4,123.45 monthly | 49,481.40; × 1.27 = 62,841.378 | **62,841.38 USD** |
| USD 90,000 annual | 90,000.00; × 1 | **90,000.00 USD** |

Why the order matters (GBP): converting monthly first gives 4,123.45 × 1.27 = 5,236.7815 → 5,236.78; ×12 = 62,841.36, versus 62,841.38 annualize-first. Tests pin these cases.

### 4.3 Amount input format *(decimal-string syntax: owner instruction; upper bound: DR-11)*
The API accepts `amount` only as a JSON **string**:
- Syntax: `^(0|[1-9][0-9]*)(\.[0-9]{1,2})?$` — digits only, optional fractional part of **1 or 2 digits**, no sign, no exponent/scientific notation (`1e5`), no thousands separators, no leading zeros (`007`), no leading/trailing whitespace, no `NaN`/`Infinity`, no empty string.
- A JSON **number** (`85000`, `85000.5`) is rejected as a structural error: `400 invalid_request`.
- A string failing the syntax (including more than two fractional digits, a sign or exponent) → `422 validation_failed` with `details.amount`.
- Value `> 0` (so `"0"`, `"0.0"`, `"0.00"` → `422 validation_failed`).
- Value ≤ the **approved upper bound (DR-11, not yet chosen)**. Separately, a value exceeding the column capacity is always rejected with the same `422 validation_failed` before reaching the database; a numeric-overflow error from PostgreSQL must never surface as a 500.
- Parsed into `BigDecimal` from the string; never via `Float`.
- Rate values in responses are strings with 8 fractional digits.

## 5. Current salary and salary history *(history preserved: Approved; mechanism: working design)*
- **Salary history** = all of an employee's salary records ordered by `effective_from`. Records are immutable except that a revision sets `effective_to` on the previously open record.
- **Current salary** = the single record with `effective_to IS NULL`.
- **Invariant:** every employee has exactly one open record, including terminated employees (DR-09). Partial unique index guarantees *at most one*; service, seed and a verification query establish *at least one*. The database cannot enforce "at least one" natively.
- Employees are created only by the seed in the MVP, so the invariant is established at creation.

## 6. Effective dates and interval integrity

### 6.1 Semantics *(half-open: Approved; type: DR-01)*
- Intervals are `[effective_from, effective_to)`: start inclusive, end exclusive; the end equals the successor's start **exactly**. No offset is ever applied: `effective_to` is never computed as "successor start minus one day" (or minus any unit); it is the same timestamp value.
- As-of rule for instant *t*: `effective_from <= t AND (effective_to IS NULL OR t < effective_to)`. At the exact boundary between A and B, **B applies**. (No MVP endpoint queries as-of; the rule governs history display, tests and future use.)
- Working default (DR-01): `timestamptz` set by the server, shown in UTC.

### 6.2 Guarantees: database vs application

| Guarantee | Mechanism | Layer |
|-----------|-----------|-------|
| At most one open-ended record per employee | Partial unique index `(employee_id) WHERE effective_to IS NULL` | DB |
| `effective_to > effective_from` when present | CHECK | DB |
| **No overlapping ranges for the same employee, including historical ones** | Exclusion constraint `EXCLUDE USING gist (employee_id WITH =, tstzrange(effective_from, effective_to, '[)') WITH &&)`; requires `btree_gist` | DB |
| **At least one** open record exists | Service, seed, verification query | App + tests |
| No gaps; A's `effective_to` equals B's `effective_from` | Revision service writes both from one timestamp value | App + tests |
| Past records are never edited | Model read-only except the `effective_to` close; service is the only writer | App + tests (DB trigger rejected as overengineering) |
| Concurrent revisions don't interleave | Employee row lock (§7) | DB lock via app |

**The partial unique index alone does not prevent historical overlaps**: it only stops two open-ended records. Two closed records `[Jan, Jun)` and `[Mar, Sep)` would pass it. The exclusion constraint prevents overlapping historical intervals (and also subsumes the one-open-record rule, since two unbounded ranges overlap). The index is kept as the lookup index for "current salary" and for a clearer error. **The exclusion constraint does not guarantee that every employee has an open record**; the service and seed verification establish that.

**Dependency:** the exclusion constraint requires `btree_gist` on every database in use. Hosted availability must be verified **before Phase 3** (DR-20). If unavailable, the only alternative is a weaker fallback (partial unique index + row lock + application overlap validation) which needs its own explicit approval and the weaker guarantee must be stated openly.

### 6.3 Same-day revisions and "equal or earlier" — DR-01 `[APPROVAL]`

| Option | Behaviour | Pros | Cons |
|--------|-----------|------|------|
| **A. Timestamps (working default)** | Server instant; several revisions per day, each with a distinct non-empty interval | A typo can be superseded at once; no calendar/time-zone ambiguity; exact maths | History shows times; HR convention is dates |
| B. Dates | `effective_from` is a date | Matches HR convention | Second same-day revision would be an empty interval `[d,d)`, so must be rejected; needs a time zone |

Under A: the client cannot supply an effective date (immediate effect), so future-dated and backdated revisions are impossible by construction. If the single effective timestamp ≤ the current record's `effective_from` (clock skew, same-microsecond race, future-dated seed) → `409 revision_conflict`; unreachable in normal use; tested with an injected clock.
Under B: the effective date would be the server's UTC date, the one-revision-per-day rule would apply, and the clock, FX-lookup and timestamp-ordering steps of §7 (steps 7–9) would change accordingly.

### 6.4 No-op revisions — DR-10 `[APPROVAL]`
Reject when amount, currency and frequency all equal the current record's: `422 no_change`. A reason-only change is not a salary revision.

## 7. Salary revision transaction and concurrency

**Procedure *(owner-specified order; the effective-timestamp type is DR-01; the token check in step 4 is the working default of DR-04 `[APPROVAL]`)***
```
 1. Authenticate / authorize the write request (controller, before any database work)
      403 writes_disabled  if no server write key is configured (checked first, whatever the request carries)
      401 unauthorized     if a key is configured and the request's key is missing or wrong
    Structural checks (controller): 400 invalid_request on malformed JSON, missing salary_revision
      object, wrong JSON types (e.g. amount not a string), or — while DR-04 is mandatory — a missing
      / non-integer expected_current_salary_record_id

BEGIN
 2. Lock the employee row:  SELECT … FROM employees WHERE id = ? FOR UPDATE     -- 404 not_found if absent
 3. Read the current (open) salary record  — AFTER the lock, never before
 4. Token check  [DR-04 — proposed mandatory]:
      409 stale_salary_record  if expected_current_salary_record_id ≠ current.id
 5. Eligibility:      422 employee_not_eligible   (status is terminated; DR-03)
 6. Validate request data and no-op:
      422 validation_failed    (amount syntax / > 0 / bound / capacity, currency exists, frequency, reason)
      422 no_change            (amount, currency and frequency equal the current record's; DR-10)
 7. Read the injected clock ONCE, after the lock; truncate ONCE to microsecond precision → effective_at
 8. Use that same effective_at for everything that needs a time:
      effective_date = effective_at.utc.to_date → FX rate lookup   (422 missing_exchange_rate if none)
      previous record's effective_to = effective_at
      new record's    effective_from = effective_at
 9. 409 revision_conflict  if effective_at is not later than current.effective_from
10. UPDATE the previous record: effective_to = effective_at   (only its closing timestamp changes)
11. INSERT the new record (fx_rate = rate from step 8, effective_from = effective_at, effective_to = NULL)
12. COMMIT — atomically
```
- **If DR-04 is resolved as optional**, a missing token skips step 4 and no longer raises `400`; all other steps are unchanged. **If it is not approved as proposed, this document must be updated.**
- **One clock read.** Steps 8–11 use the same `effective_at` value; the clock is never called independently for the FX lookup, the closure and the insert. `previous.effective_to` therefore equals `new.effective_from` exactly.
- The clock is read **after** the lock, so a transaction that waited gets a later timestamp than the one it waited on; lock order equals time order.
- Truncation to microseconds happens once so Ruby's nanosecond time equals what PostgreSQL stores (otherwise the closed `effective_to` could differ from the next `effective_from`).
- All validation (steps 4–9) happens before any write; the two writes (steps 10–11) occur in one transaction; any error rolls everything back, so there is never a closed record without a successor.
- Default `READ COMMITTED` is enough *because* the lock comes first and the current record is read after it. The current record is never read before the lock.
- The lock serializes writers; it does **not** prevent a lost update from a stale page. The optimistic token (DR-04) does, and also makes a double-click harmless (the second submit is stale).
- Close-then-insert order matters: the exclusion constraint is checked per statement, so closing first leaves no overlap at insert time.
- Resulting error precedence: 403 → 401 → 400 → 404 → 409 stale → 422 not eligible → 422 validation → 422 no-op → 422 missing rate → 409 clock conflict; mirrored in `api-contracts.md`.

## 8. Inactive and terminated employees — DR-03, DR-09 `[APPROVAL]`
Working default:

| Status | In active payroll totals | Salary revision | Shown in directory/export |
|--------|--------------------------|-----------------|----------------------------|
| `active` | Yes | Allowed | Yes |
| `on_leave` | **No** (literal reading of "active employees") | **Allowed** | Yes |
| `terminated` | No | Rejected (`employee_not_eligible`) | Yes |

- Terminated employees keep their last salary record **open**: "last salary held". This preserves the one-open-record invariant and needs no termination workflow. `terminated_on` is required iff status is `terminated`.
- Eligibility is "not terminated". `on_leave` is **not** described as ineligible anywhere; `can_revise_salary` in the API follows this table.
- Machine-readable meaning: `422 employee_not_eligible` is returned only for a status that DR-03 excludes from revisions (`terminated` under the working default). `active` and `on_leave` revisions proceed. (The earlier name `employee_not_active` is obsolete and must not be used.)
- Ambiguity: on-leave staff are usually still paid; excluding them from totals follows the brief literally. Simplest alternative: drop `on_leave`.
- The MVP has no status-change endpoint; status is set by the seed (console in emergencies).

## 9. Country or department changes — DR-13 `[APPROVAL]`
- No MVP endpoint changes them, but the model must be safe if they change.
- Analytics group by the employee's **current** country/department against the **current** salary. There is no history of either, so as-of group analytics are not supported and must not be implied.
- A country change does not change salary currency or create a salary record; a currency change needs a revision.
- Nothing is stored redundantly, so nothing goes stale.

## 10. Payroll totals and dashboard metrics

**Active payroll population** = employees with status `active` (DR-03) and their current salary record. *(Approved: "active employees"; the meaning of active is DR-03.)*

### 10.1 Definitions

| Metric | Definition |
|--------|------------|
| `active_headcount` | Count of active employees in the group |
| `total_annual_base_reporting` | `SUM(annual_reporting)`, USD, exact `numeric` |
| `average_annual_base_reporting` | `AVG(annual_reporting)`, rounded to 2 dp at output |
| `median_annual_base_reporting` | Exact `numeric` median (§10.3), rounded to 2 dp at output |
| `local_totals` (country rows only; DR-16) | Per currency in the group: `active_headcount` and `SUM(annual_local)`. Same-currency sums only |
| `low_sample` (DR-08 `[APPROVAL]`) | `true` when `active_headcount` < 10 (a named constant whose value is pending approval) |
| `status_counts` (organization section) | Employees per status for the **filtered employee population** (all three statuses, zeros included) |

Department rows show reporting currency only (a department spans currencies).

### 10.2 `status_counts` and filters
- `status_counts` counts every status; it does not apply the active-only rule.
- **Unfiltered**, it reconciles to the total employee count (10,000 in the seed).
- **With filters** (`country`, `department`, `job_level`), it reconciles to the employees matching those filters — **not** necessarily 10,000.
- `status_counts.active` always equals `organization.active_headcount`.

### 10.3 Exact numeric median — Proposed, DR-15 `[APPROVAL]`
`percentile_cont(0.5) WITHIN GROUP (ORDER BY …)` is defined in PostgreSQL for `double precision` (and `interval`) ordering values; a `numeric` sort key would be coerced to `double precision` and the result returned as `double precision`. That breaks the no-float rule, and casting salary values to `double precision` is **not** an acceptable workaround. The median is instead computed exactly:

1. Rank `annual_reporting` ascending within each group (`ROW_NUMBER() OVER (PARTITION BY group ORDER BY annual_reporting, employee_id)`).
2. Count rows per group (`COUNT(*) OVER (PARTITION BY group)`).
3. Select ranks `(n + 1) DIV 2` and `(n + 2) DIV 2` (integer division). For odd *n* these are the same row (the middle); for even *n* they are the two middle rows.
4. Median = `AVG` of the selected `numeric` values (exact), then `ROUND(…, 2)` at output (half away from zero).

Illustrative sketch (design documentation, not final code):
```sql
WITH ranked AS (
  SELECT g, annual_reporting,
         ROW_NUMBER() OVER (PARTITION BY g ORDER BY annual_reporting, employee_id) AS rn,
         COUNT(*)     OVER (PARTITION BY g)                                         AS n
  FROM current_active_compensation
)
SELECT g, ROUND(AVG(annual_reporting), 2) AS median
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)      -- integer division
GROUP BY g
```
The same definition is used for the organization (single group), each country, and each department.

**Worked examples** (values are rounded per-employee `annual_reporting`):

| Case | Values | n | Selected ranks | Median |
|------|--------|---|----------------|--------|
| Odd | 30,000.00; 45,000.00; 52,000.00; 61,000.00; 90,000.00 | 5 | 3 | **52,000.00** |
| Even | 40,000.00; 50,000.00; 60,000.00; 80,000.00 | 4 | 2, 3 | (50,000.00 + 60,000.00)/2 = **55,000.00** |
| Even, half cent | 50,000.00; 50,000.01 | 2 | 1, 2 | 50,000.005 → **50,000.01** (half away from zero) |
| Even, duplicates | 60,000.00; 60,000.00; 70,000.00; 70,000.00 | 4 | 2, 3 | (60,000.00 + 70,000.00)/2 = **65,000.00** |
| Single row | 75,000.00 | 1 | 1 | **75,000.00** |
| Large magnitude (float-regression) | 123,456,789,012.34; 123,456,789,012.35 | 2 | 1, 2 | …012.345 → **123,456,789,012.35** |
| Empty group | — | 0 | — | **null** (headcount 0, total `"0.00"`, average `null`) |

**Test plan (Phase 7):** one spec per row of this table against the real database through the analytics query object; the same cases at organization, country and department level; a spec that fails if the median expression contains a `double precision` cast or `percentile_cont`; confirm on the pinned PostgreSQL version that `percentile_cont` would have coerced (documentation check, not part of the product).

### 10.4 Empty-result contract
- A filter matching no active employees: `active_headcount: 0`, `total_annual_base_reporting: "0.00"`, `average…` and `median…`: **`null`**. `status_counts` still reports the filtered population (possibly all zero).
- Empty country and department groups are **omitted** from `by_country` / `by_department`.
- No `NaN`, `Infinity` or other invalid JSON numbers are ever emitted.

### 10.5 Caveats that must appear in UI and docs
- Every group shows **headcount** next to average/median; `low_sample` groups are visibly flagged. A median of 1–2 people is just those salaries.
- Cross-country USD comparisons conflate pay level with the fixed illustrative rates and the job-level mix. They are **comparisons, not conclusions**.
- This is **not a compa-ratio**: no salary bands or midpoints exist.
- Differences or outliers are **not evidence of pay inequity or attrition risk**; no such wording.
- A `job_level` filter lets users compare like with like.

## 11. Synthetic data rules *(synthetic and exactly 10,000: Approved; parameters: DR-17 `[APPROVAL]`)*
- Exactly **10,000** employees; all values fabricated; nothing derived from real payroll.
- Deterministic: fixed RNG seed and fixed anchor date constant (not `Date.today`); two runs yield identical data. The anchor date must be ≤ the deployment date so any new revision's `effective_from` is later than every seeded record.
- Names from curated in-repo lists (no Faker).
- Coverage: multiple countries (two sharing a currency), several currencies, several departments, job levels 1–7, the statuses chosen under DR-03, a minority of employees paid in a non-home currency.
- Statuses: majority `active`; small shares of the others; exact proportions fixed in the seed with no claim of realism.
- Salary history: a fixed share of employees has 1–3 closed historical records plus one open record; dates ordered, contiguous, after `hired_on`, and before `terminated_on` where applicable.
- At least one group with fewer than 10 active employees so `low_sample` is demonstrable.
- Employee numbers `ACME-00001` … `ACME-10000`.
- The seed refuses to run against production unless explicitly overridden and ends with verification: exactly 10,000 employees; every employee has exactly one open record; no overlaps; every record has `fx_rate`; `terminated_on` rules hold; `status_counts` sums to 10,000.

## 12. Edge-case matrix

| Edge case | Decision |
|-----------|----------|
| Several revisions on one calendar day | Allowed under timestamp effectivity (DR-01) |
| Effective instant ≤ current `effective_from` | `409 revision_conflict`; unreachable via the API (client cannot supply a date); tested with injected clock |
| Terminate an employee with a current record | Record stays open; excluded from totals; further revisions rejected (DR-09) |
| Country/department change | Current-state grouping only; salary currency unchanged (DR-13) |
| Currency without a configured rate | `422 missing_exchange_rate`; nothing written |
| Rounding differences local vs reporting | Annualize → convert once → round once (DR-06) |
| History query exactly on a boundary | Half-open: the successor applies |
| Two users revise the same employee | Row lock serializes; stale token → `409 stale_salary_record` |
| Zero or two open records | Impossible for API-created data; DB blocks two; verification detects zero |
| Non-positive, non-numeric, malformed, scientific-notation, >2 decimals, over-bound or over-capacity amount | `422 validation_failed` (JSON number → `400 invalid_request`) |
| Same-value revision | `422 no_change` (DR-10) |
| Median of 0, 1, odd, even groups | §10.3 |

## 13. Invariant register (enforcement and test)

| Invariant | Enforcement | Test |
|-----------|-------------|------|
| ≤ 1 open record per employee | Partial unique index | Model/constraint spec (Phase 3) |
| No overlapping intervals (including historical) | Exclusion constraint (DR-20); service | Constraint spec showing the partial index alone passes a historical overlap and the exclusion constraint rejects it (Phase 3) |
| ≥ 1 open record per employee | Service, seed verification | Revision spec; seed verification (Phases 4, 6) |
| `effective_to > effective_from` | CHECK | Constraint spec (Phase 3) |
| Boundary-touching ranges accepted | Half-open exclusion range | Constraint spec (Phase 3) |
| Previous `effective_to` = new `effective_from` | One timestamp value in service | Service spec with injected clock (Phase 4) |
| One clock read per revision, after the lock | Service structure | Spec with a clock double that fails on a second call; spec that the current record is read only after the lock (Phase 4) |
| Revision eligibility: `active`/`on_leave` allowed, `terminated` → `employee_not_eligible` (DR-03) | Service | One spec per status (Phase 4), request spec (Phase 5) |
| Stale token → `409 stale_salary_record` (DR-04) | Service | Stale-token and double-submit specs (Phases 4–5) |
| History never edited | Read-only model; service only | Model spec; revision spec (Phases 3–4) |
| Amount > 0, syntax, bound | CHECK `> 0` + validation | Constraint + validation specs (Phases 3–5) |
| FX rate present and > 0; no default to 1 | CHECK; service | Missing-rate spec (Phase 4) |
| `terminated_on` iff terminated | CHECK | Constraint spec (Phase 3) |
| Annualize → convert once → round once | Shared SQL fragment + Ruby | Parity spec on fixtures incl. worked examples (Phases 4, 7) |
| Totals = sum of rounded employee rows | Aggregation over rounded values | Analytics spec; dashboard total equals CSV sum for `status=active` (Phase 7) |
| Median is exact `numeric` | Window-function method | Table in §10.3 (Phase 7) |
| No raw cross-currency sums | Query design | Analytics spec with mixed currencies (Phase 7) |
| Exactly 10,000 seeded employees; determinism | Seed + verification | Seed spec; two-run fingerprint (Phase 6) |

## 14. Pending decisions
All `[APPROVAL]` items are tracked, with recommended default, trade-off and blocked phase, only in `architecture-review.md` §3 (DR-01 … DR-24). This document does not keep a separate list.
