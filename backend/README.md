# ACME Salary Management — backend

Rails 8.1 API-only application (Ruby 4.0.9, PostgreSQL). Product rules, API behaviour and the
decision register are in [`../docs`](../docs); this file covers working in `backend/`.

## Setup

Requires Ruby `4.0.9` (see `.ruby-version`) and a running PostgreSQL (the `btree_gist` extension is
needed; it ships with the standard server packages).

```sh
bundle install
bin/rails db:prepare     # creates backend_development and backend_test, loads db/schema.rb
bin/rails db:seed        # 10,000 deterministic synthetic employees
bin/rails server         # http://localhost:3000, health check at /up
```

Re-seeding: `bin/rails db:seed` is a no-op when the dataset is already present;
`RESET=1 bin/rails db:seed` replaces it. The seed refuses to run in production without
`ALLOW_PRODUCTION_SEED=1`. Verification runs inside the seed transaction, so a failure rolls back
generation or reset. Two full runs produced identical fingerprints on the disposable review database.

To try the write endpoint locally, export a key first: `export DEMO_WRITE_KEY=<anything>` (see below).

## Checks

| Command | What it does |
|---------|--------------|
| `bundle exec rspec` | Test suite (`FULL_SEED=1 bundle exec rspec --tag full_seed` adds the 10,000-row seed spec) |
| `bin/rubocop` | Style (rubocop-rails-omakase) |
| `bin/brakeman --no-pager` | Static security analysis |
| `bin/bundler-audit` | Known-vulnerability scan of gems (needs network) |
| `bin/rails zeitwerk:check` | Autoloading sanity |
| `bin/ci` | All of the above (minus Zeitwerk), plus `bin/setup` first |

No hosted CI is configured; `bin/ci` is the local equivalent.

## API (`/api/v1`, contract in `docs/api-contracts.md`)

| Endpoint | Purpose |
|----------|---------|
| `GET /employees` | Directory: search (`q`), `country`, `department`, `status`, allow-listed `sort`/`direction`, `page`/`per_page` |
| `GET /employees/:id` | Employee with current salary and the complete history, newest first |
| `GET /employees/export.csv` | Every row matching the same filters and sort, streamed, with formula-injection mitigation |
| `POST /employees/:id/salary_revisions` | The only write: closes the current salary record and opens a new one in one transaction |
| `GET /analytics/summary` | Active-payroll totals, average and exact median in USD, by country and department |
| `GET /reference_data` | Option lists for filters and the revision form |
| `GET /up` | Framework health check (outside the versioned API) |

Money and rates are decimal strings, never JSON numbers. All errors use
`{"error": {"code", "message", "details"?}}`; codes are defined only in `docs/api-contracts.md`.

### Write protection
The revision endpoint needs `Authorization: Bearer <key>` where the key is the server-side
environment variable `DEMO_WRITE_KEY`. If it is unset or empty every write returns `403
writes_disabled` (fail closed); a missing or wrong key returns `401 unauthorized`. The comparison is
constant-time and the key is never logged or echoed. Reads are open (synthetic data only).

## Configuration

Plain environment variables; see `.env.example`. There is no dotenv gem, and no secret has a
committed default. `config/master.key` is git-ignored.

## Layout

| Path | For |
|------|-----|
| `app/controllers/api/v1/` | Thin controllers: parse params, call one service or query, render JSON/CSV |
| `app/controllers/concerns/` | `ApiErrorHandling` (contract error shape) and `WriteKeyAuthentication` |
| `app/models/` | Six tables' models, plus `Compensation` (the one definition of annualization and USD conversion, in Ruby and SQL), `SalaryAmount` (amount rules) and `DecimalString` |
| `app/services/` | `SalaryRevisions::Create` (the revision workflow) and `Employees::CsvExport` |
| `app/queries/` | `Employees::Directory`, `Analytics::Summary`, `ReferenceDataQuery`, shared `ParamParsing` |
| `app/serializers/` | Plain-Ruby JSON presenters |
| `app/errors/` | `DomainError`: a business-rule failure with a contract error code |
| `lib/seeds/` | The deterministic demo dataset and its curated name pools |
| `db/migrate/`, `db/schema.rb` | Schema (`schema.rb`, DR-21): `btree_gist`, exclusion constraint, partial unique index, CHECKs |
| `spec/` | RSpec by layer: `models/`, `db/` (constraints), `services/`, `queries/`, `requests/`, `lib/` |

## Decision and verification status
Pre-existing implementation uses these approaches, now decided under delegated authority in
`docs/architecture-review.md` (owner gate sign-off pending): rounding order (DR-06, `Compensation`), currency independent of
country (DR-07), no-op revisions rejected (DR-10), low-sample threshold 10 (DR-08,
`Analytics::Summary::LOW_SAMPLE_THRESHOLD`), exact numeric median (DR-15), analytics filters and
`local_totals` (DR-16), seed proportions (DR-17), the write key (DR-02) and the unpaginated salary
history (DR-19).

The backend review verified 344 specs (including two full deterministic seed runs), fresh migrations,
the corrective migration's rollback/reapply, schema loading and fresh `db:prepare` on isolated
PostgreSQL 14.25 databases. RuboCop, autoloading, Brakeman and the cached dependency audit passed.
The earlier architecture audit's database limitation is historical; see the current
[`backend review`](../docs/backend-review.md) for commands, defects and limitations.

One corrective migration rejects numeric `NaN` in salary amounts and FX rates, which a positive-value
CHECK alone accepted. Existing NaN data must be investigated before applying that migration; it
deliberately fails validation rather than deleting or rewriting any existing data. No user database
was migrated during the review.

**G1 remains OPEN.** Hosted DR-20 verification and DR-22 remain outstanding. The current user request
authorized backend review/corrections while retaining those gates; local results do not constitute
phase acceptance or hosted verification. Tests on the eventual hosted PostgreSQL major (17/18),
deployment security and proxy-log checks are still required.
