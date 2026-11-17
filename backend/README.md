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

Before seeding, verify `RAILS_ENV=development`, the database identity and all six application-table
counts. The default is the local `backend_development` database; `DATABASE_URL` can override it.
Do not run prepare/seed against a hosted, shared or uncertain connection. No full-seed flag is
required: `RAILS_ENV=development bin/rails db:seed` generates exactly 10,000 employees by default.

Re-seeding without `RESET` is a verified no-op when employees already exist and the expected count
and history invariants pass; it preserves salary revisions rather than replacing the dataset.
This verification is not a comparison against the original seed fingerprint. Partial/unrelated data
must be investigated first. Reference-only partial data can also cause insertion to fail and roll
back; do not delete it automatically. `RESET=1` is destructive and must not be used on an existing
development database without explicit approval. The production override is also not authorization
to seed production. Verification runs inside the generation transaction, so failure rolls it back.

### Local seed verification (17 November 2026)

The normal Homebrew PostgreSQL 14.25 development database was confirmed to be local and empty
before running the existing seed unchanged. It now contains 10,000 employees, 16,055 salary records
(6,055 historical and 10,000 open), 6 countries, 9 departments, 4 currencies and 4 exchange rates.
Statuses: 9,200 active, 300 on leave, 500 terminated. All 21 read-only integrity checks passed,
including overlaps/gaps, required open records, finite positive values, FX snapshots and foreign keys.

The full fingerprint matches the earlier independent seed runs:
`040a37bf54ff252c0fd5cae2dfe83d35c975099c817f40cb820e95c2b08b882a`.
A rerun with PostgreSQL writes disabled returned `already_seeded: true` and the same fingerprint:

```sh
# From backend/, after confirming the local connection; RESET must be unset.
PGOPTIONS='-c default_transaction_read_only=on' RAILS_ENV=development bin/rails db:seed

# Read-only current counts and generator invariant verification:
RAILS_ENV=development bin/rails runner 'c = ActiveRecord::Base.connection; c.execute("SET default_transaction_read_only = on"); puts({environment: Rails.env, database: c.select_value("SELECT current_database()"), summary: Seeds::DemoDataset.new.verify!, exchange_rates: ExchangeRate.count}.inspect)'
```

The full backend suite passed again: `FULL_SEED=1 bundle exec rspec --seed 47214` — 344 examples,
0 failures, 25.32 seconds, including full-size determinism/reset/rollback coverage. It ran only on a
separate newly created disposable local test database, never development. RuboCop (82 files) and
Zeitwerk passed. Running localhost APIs passed read-only directory/search/pagination/profile/history,
filters, analytics and CSV checks. Real Chrome also verified React dashboard, search, profile/history
and country filtering against these development rows. No salary write was made for integration.

The documented country/department/status/level allocations match exactly. Current salaries use all
four currencies and both frequencies (5,545 monthly; 4,455 annual). Employee numbers are unique;
fictional names come from curated pools and intentionally repeat (4,247 distinct name pairs).
Seed execution time was not separately measured; suite timing is not a seed benchmark. No seed
logic, dependencies, frontend code or gate decisions changed. G1 and hosted verification remain open.

To try the write endpoint locally, export a key first: `export DEMO_WRITE_KEY=<anything>` (see below).

## Checks and test isolation

Run tests in a **separate terminal**. First run the database-free guard regressions:

```sh
bundle exec rspec spec/safety/test_database_safety_spec.rb
ruby script/prepare_test_database.rb
```

The preparation script creates a NEW local PostgreSQL database, marks it with a random disposable
attestation, loads the existing schema and prints the path of a mode 0600 shell environment file.
It refuses existing/protected names and remote hosts; it never seeds, resets, truncates or drops an
existing database. Source the exact printed file in this test terminal, then run:

```sh
FULL_SEED=1 bundle exec rspec --seed 47214
bin/rubocop --cache false
bin/rails zeitwerk:check
bundle exec brakeman --no-threads --quiet --no-pager --exit-on-warn --exit-on-error
bundle exec bundler-audit check --no-update   # cached advisory evidence, not a freshness check
```

The test environment file contains `RAILS_ENV=test`, `RACK_ENV=test`, the explicit local
`DATABASE_URL`/PG host/port, `ACME_TEST_DATABASE` and `ACME_TEST_DATABASE_TOKEN`. Keep it outside Git.
These are test-target declarations, never the demo write key. Do not source it into the development
server terminal. A previously confirmed disposable local target can use the same declarations only
when its owner has explicitly established the matching database comment attestation; the guard
accepts no name-substring shortcut, and unknown targets must not be adopted automatically.

`spec/rails_helper.rb` validates environment before Rails boot, installs the PostgreSQL factory
guard before any Rails connection, and verifies the primary connection before schema maintenance.
Every new adapter connection (including later pools/reconnects) starts read-only, checks its actual
name/local server/owner/non-replica identity and matching database-comment marker, then enables
writes. Wrong/missing declarations, development/production targets, service/address overrides and
remote/unattested targets fail closed. Existing suite database access uses this adapter; do not
introduce unguarded raw-driver/alternate-adapter connections in specs.

Ordinary `bundle exec rspec` excludes the full-size seed example; `FULL_SEED=1` includes it. The full
suite intentionally changes disposable fixtures and exercises reset/rollback scenarios there.
Never run it on development data. `bin/ci` also invokes setup and a network advisory update; use the
verified test environment before invoking it. Do not casually export a development DATABASE_URL
into a test terminal.

Latest QA: 358 examples pass, including 6 database-free safety subprocess cases, Unicode reason
boundaries and exact CSV timestamp precision. CSV now uses the shared UTC microsecond formatter;
the API's general convention applies and there is no explicit CSV precision exception. Stored dates
are unchanged. For disposable browser fixtures/long-history measurements see
[`docs/local-browser-smoke.md`](../docs/local-browser-smoke.md) and
[`docs/final-local-qa.md`](../docs/final-local-qa.md). Earlier sections/reports retain their historical
results; the current run does not close G1 or hosted verification.

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
