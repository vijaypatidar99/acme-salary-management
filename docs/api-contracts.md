# API Contracts

**Precedence:** rank 5 in the hierarchy defined in `architecture-review.md` §1; consistent with `domain-decisions.md` and `architecture.md`, which win on conflict.
**Status:** Proposed — no endpoint exists yet. Items tagged **`[APPROVAL DR-nn]`** are pending decisions tracked only in the register (`architecture-review.md` §3). Where a tag appears, the text describes the recommended working default.
Base path: `/api/v1`.

## Conventions

- JSON, UTF-8. Timestamps ISO 8601 UTC with microseconds (`2026-11-17T09:30:00.123456Z`); dates `YYYY-MM-DD`. (Timestamp type: DR-01.)
- **Money is a decimal string** (`"85000.00"`), rates are decimal strings with 8 fractional digits (`"0.01200000"`). Never JSON numbers. The frontend formats for display only and does no arithmetic.
- Reporting currency is `USD`; reporting values carry the `_reporting` suffix (`annual_base_reporting`), and responses state `"reporting_currency": "USD"`.
- **Strictness:** unknown filter values, unknown sort fields and malformed paging values (on `GET /employees`) return `400` rather than being silently ignored.
- Reference identifiers: `country` = ISO alpha-2 code; `department` = numeric department id.

### Decimal-string format for `amount` (request)
Defined once in `domain-decisions.md` §4.3. Summary: JSON **string** matching `^(0|[1-9][0-9]*)(\.[0-9]{1,2})?$`; no sign, no exponent/scientific notation, no thousands separators, no leading zeros, no whitespace; at most two fractional digits; value `> 0`; value ≤ the approved upper bound **[APPROVAL DR-11 — exact number not yet chosen]**; values beyond column capacity get the same rejection (never a database error).
- JSON **number** instead of string → `400 invalid_request`.
- String with wrong syntax, >2 decimals, sign, exponent, zero, over bound/capacity → `422 validation_failed` with `details.amount`.

### Error shape
```json
{ "error": { "code": "validation_failed", "message": "Amount must be greater than 0", "details": { "amount": ["must be greater than 0"] } } }
```
`details` is optional. **Codes are the stable contract**; messages are for humans. This table is the only definition of error codes.

| Status | Code | Condition |
|--------|------|-----------|
| 400 | `invalid_parameter` | Malformed/unsupported query parameter (bad `status`, `sort`, `direction`; `page` not a positive integer; `per_page` outside 1–100; unknown `country`/`department`; `q` too long; bad `job_level`) |
| 400 | `invalid_request` | Request body missing, not valid JSON, missing the `salary_revision` object, a field has the wrong JSON type (e.g. `amount` is a number; a `null` field is treated as absent and reported as `422 validation_failed`), or — while DR-04 is mandatory — `expected_current_salary_record_id` is missing or not an integer |
| 401 | `unauthorized` | A write key is configured on the server and the request's key is missing or wrong |
| 403 | `writes_disabled` | No write key is configured on the server (fail closed) |
| 404 | `not_found` | Unknown employee or unknown route |
| 409 | `stale_salary_record` | `expected_current_salary_record_id` ≠ the employee's current record id (someone else revised, or a double submit). Body includes `current_salary_record_id`. **Proposed mandatory behaviour, DR-04 `[APPROVAL]`** |
| 409 | `revision_conflict` | The server's effective timestamp is not later than the current record's `effective_from` (clock skew; should not occur) |
| 422 | `employee_not_eligible` | The employee's status does not allow salary revisions. Under the DR-03 working default: `terminated` is rejected; `active` and `on_leave` are allowed. Body `details.employment_status`. (The earlier name `employee_not_active` is obsolete.) |
| 422 | `validation_failed` | Amount/currency/frequency/reason invalid or absent (syntax, ≤ 0, > 2 decimals, over bound or capacity, unknown currency, bad frequency, blank/over-long/missing reason, missing or `null` amount/currency/frequency) |
| 422 | `no_change` | Amount, currency and frequency equal the current record's (DR-10) |
| 422 | `missing_exchange_rate` | No `currency → USD` rate on or before the UTC date of the effective timestamp. Nothing is written; never defaults to 1 |
| 500 | `internal_error` | Unexpected failure. The body is generic: **no exception message, class name, backtrace, SQL or request echo is ever returned**; diagnostics stay in server-side logs (never containing the `Authorization` header or secrets) |

### Authorization
- All `GET` endpoints are open **because all data is synthetic** (demo-only decision).
- `POST` requires `Authorization: Bearer <demo write key>` over HTTPS. The key is never in URLs, query parameters, `VITE_*` variables or logs. **[APPROVAL DR-02]** (details: `architecture.md` §9.3).
- **Precedence when the server has no configured write key:** `403 writes_disabled` is returned for **every** write request, whether or not a header is supplied, before any other check. When a key is configured: missing or wrong → `401 unauthorized`.
- No per-user identity; no audit attribution.

### Error precedence for `POST …/salary_revisions`
Mirrors the step order of `domain-decisions.md` §7 (authoritative):
1. `403 writes_disabled` (no server key configured; **before everything else, with or without a header**, so the fail-closed policy cannot be bypassed) → 2. `401 unauthorized` (key configured; missing or wrong) → 3. `400 invalid_request` (structural) → 4. `404 not_found` (employee, found when taking the row lock) → 5. `409 stale_salary_record` (DR-04 `[APPROVAL]`) → 6. `422 employee_not_eligible` → 7. `422 validation_failed` → 8. `422 no_change` → 9. `422 missing_exchange_rate` (after the single clock read) → 10. `409 revision_conflict`. The first failing check wins; checks 5–10 are all evaluated before any write, and no error leaves partial changes (the previous record is never closed without its successor being inserted in the same transaction).

### Client handling expected (matches `architecture.md` §9.3)
`401` re-prompt for the passphrase (and clear it) · `403` show editing disabled · `409 stale_salary_record` reload employee and ask the user to review · `409 revision_conflict` retry message · `422` show field/business errors · `400` generic error · `500` generic error. No automatic retry of `POST`.

---

## 1. `GET /api/v1/employees`

**Purpose:** paginated, filterable, sortable directory with each employee's current salary. Read-only.

### Query parameters

| Param | Type | Default | Rules |
|-------|------|---------|-------|
| `q` | string | — | Trimmed, ≤ 100 chars. Case-insensitive contains-match on first name, last name, "first last" and `employee_number`. Empty = no search |
| `country` | string | — | ISO alpha-2, must exist |
| `department` | integer | — | Must exist |
| `status` | string | — | `active` \| `on_leave` \| `terminated` (DR-03) |
| `sort` | string | `employee_number` | `employee_number`, `name`, `country`, `department`, `job_level`, `hired_on`, `status`, `annual_base_reporting` |
| `direction` | string | `asc` | `asc` \| `desc` |
| `page` | integer | 1 | Positive integer. Zero, negative or malformed → `400 invalid_parameter`. **A page beyond the last page → `200` with empty `data`** and correct `meta` |
| `per_page` | integer | 25 | 1–100, otherwise `400 invalid_parameter` (DR-18) |

`name` sorts by `last_name, first_name`. Every sort appends `id` as the tie-breaker. `annual_base_reporting` sorts on the USD-converted value (local amounts are not comparable). Employees without a current salary (not expected) sort last.

### 200 response
```json
{
  "data": [
    {
      "id": 42,
      "employee_number": "ACME-00042",
      "first_name": "Asha",
      "last_name": "Rao",
      "job_title": "Senior Engineer",
      "job_level": 4,
      "department": { "id": 3, "name": "Engineering" },
      "country": { "code": "IN", "name": "India" },
      "employment_status": "active",
      "hired_on": "2019-04-01",
      "current_salary": {
        "id": 9001,
        "amount": "250000.00",
        "currency": "INR",
        "pay_frequency": "monthly",
        "annual_base_local": "3000000.00",
        "annual_base_reporting": "36000.00",
        "effective_from": "2025-04-01T00:00:00.000000Z"
      }
    }
  ],
  "meta": { "page": 1, "per_page": 25, "total_count": 10000, "total_pages": 400, "reporting_currency": "USD" }
}
```
Page beyond the end: `"data": []`, `meta` otherwise unchanged (`total_count`, `total_pages` still the real values). `total_pages = ceil(total_count / per_page)`, so an empty result set has `total_count: 0`, `total_pages: 0`, and every valid `page` (including 1) returns `"data": []` with `200`.

### Errors
`400 invalid_parameter` (details name the parameter).

---

## 2. `GET /api/v1/employees/:id`

**Purpose:** one employee with the current salary and the complete salary history, newest first. Read-only.

**Salary history is returned newest first, unpaginated and unbounded — an intentional MVP trade-off [APPROVAL DR-19].** Revisions can accumulate indefinitely, so **no maximum number of records is guaranteed** and the payload grows with every revision. (The seed gives each employee a small number of historical records by design; that says nothing about real use.) Phase 10 measures a long-history fixture; a paginated history endpoint is the documented follow-up if that shows a problem.

### 200 response
```json
{
  "data": {
    "id": 42,
    "employee_number": "ACME-00042",
    "first_name": "Asha",
    "last_name": "Rao",
    "job_title": "Senior Engineer",
    "job_level": 4,
    "department": { "id": 3, "name": "Engineering" },
    "country": { "code": "IN", "name": "India" },
    "employment_status": "active",
    "hired_on": "2019-04-01",
    "terminated_on": null,
    "can_revise_salary": true,
    "current_salary": { "id": 9001, "…": "same shape as a salary_history item" },
    "salary_history": [
      {
        "id": 9001, "amount": "250000.00", "currency": "INR", "pay_frequency": "monthly",
        "fx_rate": "0.01200000", "annual_base_local": "3000000.00", "annual_base_reporting": "36000.00",
        "effective_from": "2025-04-01T00:00:00.000000Z", "effective_to": null,
        "reason": "Annual review", "is_current": true
      },
      {
        "id": 8120, "amount": "230000.00", "currency": "INR", "pay_frequency": "monthly",
        "fx_rate": "0.01200000", "annual_base_local": "2760000.00", "annual_base_reporting": "33120.00",
        "effective_from": "2023-04-01T00:00:00.000000Z", "effective_to": "2025-04-01T00:00:00.000000Z",
        "reason": "Promotion", "is_current": false
      }
    ],
    "reporting_currency": "USD"
  }
}
```
`can_revise_salary` is `true` for `active` **and** `on_leave`, `false` for `terminated` (DR-03 working default). It is a UI hint; the server enforces eligibility independently (`422 employee_not_eligible`). `on_leave` is not described as ineligible.

### Errors
`404 not_found`.

---

## 3. `POST /api/v1/employees/:id/salary_revisions`

**Purpose:** record a new base salary effective immediately; closes the current record and creates the new one in one transaction; never edits past values. The only write endpoint. No effective-date field exists: future-dated and backdated revisions are impossible by construction (DR-01).

### Headers
`Authorization: Bearer <demo write key>`, `Content-Type: application/json`.

### Request body
```json
{
  "salary_revision": {
    "amount": "270000.00",
    "currency": "INR",
    "pay_frequency": "monthly",
    "reason": "Annual review",
    "expected_current_salary_record_id": 9001
  }
}
```

| Field | Rules |
|-------|-------|
| `amount` | Required string, format in "Decimal-string format" above; `> 0`; ≤ the upper bound **[APPROVAL DR-11 — value not yet chosen]** |
| `currency` | Required; must exist in `currencies`; must have a usable rate (server re-checks) |
| `pay_frequency` | Required; `monthly` \| `annual` |
| `reason` | Required; non-blank after trimming; ≤ 255 chars (DR-12) |
| `expected_current_salary_record_id` | Integer. **Proposed required [APPROVAL DR-04]**: while mandatory, missing/non-integer → `400 invalid_request`, and a value ≠ the current record id at lock time → `409 stale_salary_record`. If DR-04 is resolved as optional, an absent field skips the check |

### Procedure (authoritative text: `domain-decisions.md` §7)
Authenticate → lock employee → read current record (after the lock) → token check (DR-04) → eligibility → validate request data and no-op → read the injected clock **once**, truncate once to microseconds → using that same timestamp: FX lookup by its UTC date, `effective_to` of the previous record, `effective_from` of the new record → reject if the timestamp is not later than the current record's `effective_from` → close previous → insert new → commit.

### 201 response
```json
{
  "data": {
    "employee_id": 42,
    "current_salary": {
      "id": 9150, "amount": "270000.00", "currency": "INR", "pay_frequency": "monthly",
      "fx_rate": "0.01200000", "annual_base_local": "3240000.00", "annual_base_reporting": "38880.00",
      "effective_from": "2026-11-17T09:30:00.123456Z", "effective_to": null,
      "reason": "Annual review", "is_current": true
    },
    "previous_salary": {
      "id": 9001, "effective_to": "2026-11-17T09:30:00.123456Z", "is_current": false,
      "…": "full record shape"
    },
    "reporting_currency": "USD"
  }
}
```
`previous_salary.effective_to` equals `current_salary.effective_from` exactly.

### Errors
`403 writes_disabled`, `401 unauthorized`, `400 invalid_request`, `404 not_found`, `409 stale_salary_record`, `422 employee_not_eligible`, `422 validation_failed`, `422 no_change`, `422 missing_exchange_rate`, `409 revision_conflict` — conditions and precedence above. On any error no record is closed or created.

---

## 4. `GET /api/v1/analytics/summary`

**Purpose:** compensation overview for the **active payroll population** in USD, with local-currency detail on country rows. Read-only; computed in SQL. Definitions: `domain-decisions.md` §10.

### Query parameters (optional; narrow the whole summary) **[APPROVAL DR-16]**
`country` (ISO alpha-2), `department` (id), `job_level` (1–7). Invalid → `400 invalid_parameter`. No pagination (bounded by the number of countries and departments). Groups sorted by `total_annual_base_reporting` descending, then name.

### 200 response (numbers are illustrative placeholders, not seeded results)
```json
{
  "data": {
    "reporting_currency": "USD",
    "filters": { "country": null, "department": null, "job_level": null },
    "organization": {
      "active_headcount": 9211,
      "total_annual_base_reporting": "612345678.90",
      "average_annual_base_reporting": "66480.51",
      "median_annual_base_reporting": "61200.00",
      "status_counts": { "active": 9211, "on_leave": 289, "terminated": 500 }
    },
    "by_country": [
      {
        "country": { "code": "IN", "name": "India" },
        "active_headcount": 1500,
        "low_sample": false,
        "total_annual_base_reporting": "54000000.00",
        "average_annual_base_reporting": "36000.00",
        "median_annual_base_reporting": "34000.00",
        "local_totals": [
          { "currency": "INR", "active_headcount": 1490, "total_annual_base_local": "4500000000.00" },
          { "currency": "USD", "active_headcount": 10, "total_annual_base_local": "900000.00" }
        ]
      }
    ],
    "by_department": [
      {
        "department": { "id": 3, "name": "Engineering" },
        "active_headcount": 2400,
        "low_sample": false,
        "total_annual_base_reporting": "190000000.00",
        "average_annual_base_reporting": "79166.67",
        "median_annual_base_reporting": "75000.00"
      }
    ],
    "notes": [
      "Averages and medians are comparisons only, not pay-equity conclusions.",
      "Reporting-currency values use fixed illustrative exchange rates."
    ]
  }
}
```

### Semantics
- Payroll metrics (`active_headcount`, totals, average, median, `local_totals`) include **only the active-payroll population** (DR-03).
- **Median** is the exact `numeric` median defined in `domain-decisions.md` §10.3 (middle value for odd n; mean of the two middle values for even n; rounded to 2 dp at output), identical for organization, country and department rows (DR-15).
- **`status_counts`** includes **all** statuses (all three keys always present, zeros included) for the **filtered employee population**. With no filters it reconciles to the total employee count (10,000 in the seed). With filters it reconciles to the employees matching those filters, not necessarily 10,000. `status_counts.active` equals `organization.active_headcount`.
- `low_sample` is `true` when `active_headcount` < the low-sample threshold (a named constant; proposed value 10 **[APPROVAL DR-08]**). `local_totals` appears on country rows only and each entry sums a single currency; department rows carry no local totals because a department spans currencies. Group size (`active_headcount`) is always present beside average and median. Averages and medians are descriptive comparisons, not compa-ratios and not evidence of pay inequity or attrition risk.
- **Empty result contract:** a filter matching no active employees returns `active_headcount: 0`, `total_annual_base_reporting: "0.00"`, `average_annual_base_reporting: null`, `median_annual_base_reporting: null`; `by_country` and `by_department` are `[]`. Empty country/department groups are always omitted. `NaN`, `Infinity` and other invalid JSON numbers are never emitted.

### Errors
`400 invalid_parameter`.

---

## 5. `GET /api/v1/employees/export.csv`

**Purpose:** download **all** employee/current-salary rows matching the directory filters, in the directory's sort order. Read-only. Routed **before** `/employees/:id` so `export` is not parsed as an id.

### Query parameters
Same `q`, `country`, `department`, `status`, `sort`, `direction` as `GET /employees`, with the same allow-lists, defaults (`sort=employee_number`, `direction=asc`), stable `id` tie-breaker and strict `400 invalid_parameter` validation. **`page` and `per_page` are not used** (ignored if supplied); all matching records are exported. The frontend export link carries the current filters, sort and direction.

### Response
- `200`, `Content-Type: text/csv; charset=utf-8`, `Content-Disposition: attachment; filename="employees-YYYYMMDD.csv"`.
- Header row, comma delimiter, RFC 4180 quoting; rows streamed in batches; no row cap.
- Text cells are sanitized against spreadsheet formula injection by the policy below.

### Formula-injection sanitization policy (deterministic)
CSV quoting/escaping **alone does not prevent formula injection**; a spreadsheet interprets a cell's content after parsing. The export therefore applies a separate, deterministic mitigation **before** RFC 4180 encoding:

1. **Which cells.** *Text* columns: `employee_number`, `first_name`, `last_name`, `department`, `country_code`, `country`, `job_title`, `employment_status`, `salary_currency`, `pay_frequency`. *Numeric* columns (`job_level`, `salary_amount`, `annual_base_local`, `fx_rate_to_usd`, `annual_base_usd`) and *date/timestamp* columns (`hired_on`, `terminated_on`, `salary_effective_from`) are produced by the system from typed values and are written **verbatim, never prefixed** — so a numeric value that happens to be negative stays a valid number.
2. **Risky text.** Let `lead` be the cell value after skipping any leading run of whitespace and control characters (Unicode White_Space and control characters: space, TAB, CR, LF, NBSP and other control characters). A text value is **risky** if (a) its very first character is TAB, CR or LF, **or** (b) the first character of `lead` is `=`, `+`, `-` or `@`.
3. **Fix.** Prefix a risky value with a single apostrophe `'`, preserving every original character (including leading whitespace) after it.
4. **Then** apply RFC 4180 encoding to the (possibly prefixed) value: wrap in double quotes if it contains a comma, double quote, CR or LF; double any embedded double quotes.
5. Missing values (`NULL`) are empty fields.

Limits: this is a mitigation, not a guarantee for every spreadsheet application, and some applications show the apostrophe literally. Consumers must still treat exported files as untrusted input.

**Required test cases** (expected value shown before RFC quoting; "→ quoted" means step 4 also applies). Legend for invisible characters: `␠` = space, `⇥` = TAB (U+0009), `↵` = CR (U+000D), `⏎` = LF (U+000A).

| Text value | Expected cell |
|------------|---------------|
| `=1+1`, `+1`, `-1`, `@SUM(A1)` | `'=1+1`, `'+1`, `'-1`, `'@SUM(A1)` |
| `␠=1+1` (leading space), `␠␠-2`, `␠@x` | prefixed: `'␠=1+1`, `'␠␠-2`, `'␠@x` |
| `⇥=1+1` (leading TAB) | `'⇥=1+1` |
| `↵=1+1` (leading CR), `⏎=1+1` (leading LF) | prefixed, then → quoted (contains CR/LF) |
| `=HYPERLINK("http://x","y")` | `'=HYPERLINK("http://x","y")`, → quoted with doubled quotes |
| `Smith, John` | unchanged value, → quoted `"Smith, John"` |
| `say "hi"` | unchanged value, → quoted `"say ""hi"""` |
| `line1⏎line2` (embedded newline, not leading) | unchanged value, → quoted |
| `Engineering`, `O-Neil`, `a=b` | unchanged (first non-blank char is safe) |
| Text value `-100.00` (e.g. in `job_title`) | `'-100.00` |
| Numeric column value `-100.00` (hypothetical negative in a numeric column) | `-100.00`, **not** prefixed |
| Numeric column `250000.00`, date `2019-04-01` | unchanged |
| `NULL` `terminated_on` | empty field |

### Columns (in order)

| Column | Example |
|--------|---------|
| `employee_number` | `ACME-00042` |
| `first_name` | `Asha` |
| `last_name` | `Rao` |
| `department` | `Engineering` |
| `country_code` | `IN` |
| `country` | `India` |
| `job_title` | `Senior Engineer` |
| `job_level` | `4` |
| `employment_status` | `active` |
| `hired_on` | `2019-04-01` |
| `terminated_on` | *(blank)* |
| `salary_amount` | `250000.00` |
| `salary_currency` | `INR` |
| `pay_frequency` | `monthly` |
| `annual_base_local` | `3000000.00` |
| `fx_rate_to_usd` | `0.01200000` |
| `annual_base_usd` | `36000.00` |
| `salary_effective_from` | `2025-04-01T00:00:00Z` |

The export includes **every status that matches the filters**: unless the `status` filter is supplied it contains `active`, `on_leave` **and** `terminated` employees. Its `annual_base_usd` column therefore does **not** always equal the dashboard `total_annual_base_reporting`; the two agree only when the export is filtered to `status=active` and the dashboard has the same `country`/`department` scope, no `job_level` filter (the directory and export have none), and the export has no `q` search. The UI says so beside the export button.

### Errors
`400 invalid_parameter`. An empty result is `200` with the header row only.

---

## 6. `GET /api/v1/reference_data` **[APPROVAL DR-14]**

**Purpose:** option lists for filters and the revision form so the frontend hard-codes no domain lists. Read-only.

```json
{
  "data": {
    "reporting_currency": "USD",
    "countries": [{ "code": "IN", "name": "India" }],
    "departments": [{ "id": 3, "name": "Engineering" }],
    "currencies": [{ "code": "INR", "name": "Indian Rupee", "has_rate": true }],
    "employment_statuses": ["active", "on_leave", "terminated"],
    "pay_frequencies": ["monthly", "annual"],
    "job_levels": [1, 2, 3, 4, 5, 6, 7],
    "low_sample_threshold": 10
  }
}
```
**`has_rate` definition:** `true` when a usable `currency → USD` rate exists, using the lookup policy in `domain-decisions.md` §3.3 (the row with the greatest `effective_on` ≤ the **current UTC date**; USD qualifies through its identity row). It is advisory: the revision endpoint independently re-validates with the effective timestamp's UTC date and returns `422 missing_exchange_rate` if there is none. The revision form offers only `has_rate: true` currencies. `low_sample_threshold` is the named constant of DR-08 `[APPROVAL]` (proposed value 10); this field is added when DR-08 is approved (Phase 7).

---

## Field definitions (every field has a rule)

| Field | Rule / source |
|-------|---------------|
| `employee_number`, names, `job_title`, `job_level`, `hired_on`, `terminated_on` | Stored employee attributes (`architecture.md` §4.4) |
| `department`, `country` | Current employee state (DR-13) |
| `employment_status` | Stored; meaning per DR-03 |
| `can_revise_salary` | `employment_status <> terminated` (DR-03/DR-09) |
| `current_salary` | The record with `effective_to IS NULL` (`domain-decisions.md` §5) |
| `amount`, `currency`, `pay_frequency`, `reason` | Stored on the salary record |
| `fx_rate` | Snapshot on the record (DR-05); lookup policy `domain-decisions.md` §3.3 |
| `annual_base_local` | `amount × (12 \| 1)` (§2) |
| `annual_base_reporting` | `ROUND(annual_base_local × fx_rate, 2)` (§4.2, DR-06) |
| `effective_from`, `effective_to` | Half-open interval (§6); server timestamp (DR-01) |
| `is_current` | `effective_to IS NULL` |
| `meta.*` | Pagination arithmetic over the filtered count |
| `active_headcount`, `total_…`, `average_…`, `median_…`, `low_sample`, `local_totals`, `status_counts` | `domain-decisions.md` §10 |
| `has_rate`, `low_sample_threshold` | §3.3 and DR-08 |
| `fx_rate_to_usd`, `annual_base_usd`, `salary_*` (CSV) | Same definitions as the JSON fields above |
| `data`, `meta` | Envelope: `data` holds the resource(s); `meta` appears only on the paginated list |
| `employee_id`, `previous_salary` (revision response) | The revised employee's id; the just-closed record, whose `effective_to` equals the new record's `effective_from` (`domain-decisions.md` §7) |
| `reporting_currency` | System constant `USD` (`domain-decisions.md` §3.2) |
| `filters` (analytics) | Echo of the validated optional filters (DR-16); `null` when absent |
| `notes` (analytics) | Fixed descriptive caveat strings (`domain-decisions.md` §10.5); contain no computed values |
| `employment_statuses`, `pay_frequencies`, `job_levels`, `countries`, `departments`, `currencies` (reference data) | Allowed values/rows from the stored reference tables and the CHECK-constrained lists (`architecture.md` §4) |
| `current_salary_record_id` (in `409 stale_salary_record`) | The employee's real current record id at lock time |

## Not in the API (by design)
Employee create/update/delete, termination, salary-record update/delete, rate management, as-of queries, bulk import, auth/session endpoints, user management. Each is excluded by the brief or has no MVP use case. The framework health route (used for infrastructure checks) is outside this contract.
