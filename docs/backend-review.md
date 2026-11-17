# Backend review and correction report — 17 November 2026

The current user request explicitly authorized backend review, fixes, corrective migrations and tests while keeping G1 OPEN. That authorization supersedes the earlier documentation-only implementation hold for this task. Architecture decisions and product scope were not changed. The previous `audit-report.md` remains a historical architecture audit; its inability to run database checks was resolved here using a separately isolated local cluster.

## A. Backend implementation inventory

COMPLETE here means the reviewed local implementation matches the documented behavior and relevant tests passed on PostgreSQL 14.25. It does not mean hosted compatibility, deployment readiness or phase acceptance. Git cannot establish the author of uncommitted files; “prior implementation” means present at entry.

| Area | Entry assessment after review | Final status | Evidence |
|------|-------------------------------|--------------|----------|
| Database | INCORRECT: positive numeric CHECKs accepted NaN; otherwise existing tables/constraints worked | COMPLETE locally | Direct-SQL regression tests; six-table migrations, rollback/reapply and schema-load comparison passed |
| Models | INCORRECT: raw amount precision/syntax not protected, reason not normalized, closed records editable/deletable | COMPLETE locally | Validation and append-only regression specs plus existing association/scope specs |
| Employees | INCORRECT edge cases: malformed path IDs coerced, NUL query input caused server errors | COMPLETE locally | Search/filter/sort/pagination/query-count and new malformed-input request tests |
| Compensation | Existing implementation matched reviewed behavior | COMPLETE locally | Current salary/history serializers, fixed decimal-string output and SQL/Ruby parity specs |
| Salary revisions | Core workflow correct; surrounding model/input gaps | COMPLETE locally | Employee row lock, stale token, eligibility, one-clock timestamp, same-day changes, rollback and two-connection race tests |
| FX | Existing direction/lookup/snapshot/formula correct; NaN DB gap | COMPLETE locally | Numeric constraints and parity/lookup/snapshot specs; no financial arithmetic added to frontend |
| Analytics | Existing numeric aggregation correct; test gaps at exact threshold and CSV reconciliation | COMPLETE locally | Exact medians at all three grouping levels, filters/status counts, empty groups, threshold10 and active-only CSV reconciliation |
| Reference data | Existing implementation matched reviewed behavior | COMPLETE locally | Database-derived lists, constants and usable-rate/date behavior verified |
| Seed | INCORRECT failure path: verification happened after commit, so a failed reset could replace prior data | COMPLETE locally | Verification rollback specs; exactly10,000, invariants, rerun/no-op and matching full-size fingerprints |
| Security | INCORRECT: raw exception messages and Authorization diagnostics could expose credentials; wildcard CORS env accepted | COMPLETE for local demo boundary; deployment PARTIAL | New log/parameter-filter/CORS tests; existing key/error/CSV/injection tests; proxy/TLS checks still pending |
| API contracts | Existing six endpoints implemented; malformed-ID and input failure behavior incorrect | COMPLETE locally | Request specs for shapes, money strings, error codes/precedence, paging, filtering, history and export |
| Tests | 324 ordinary specs passed but missed confirmed defects; concurrency waits could hang on a failure | COMPLETE for current local suite | 19 new examples, full-seed rerun strengthened, bounded thread waits/cleanup; final344 examples passed |

## B. Existing code preserved

The original service correctly locked the employee before reading the current record, checked the mandatory token before eligibility, validated before writing, read/truncated the clock once, selected the rate using that UTC timestamp, closed before inserting and committed both changes atomically. Its transaction/order/rollback structure was preserved.

The directory already shared filters/order with export, escaped LIKE metacharacters, allow-listed sorts, used stable ID tie-breaking, handled empty/out-of-range pages and avoided N+1 loading. Exact PostgreSQL numeric medians, per-row annualization/conversion/rounding, active-only totals, all-status filtered counts, reference data, JSON money strings and CSV sanitization were retained. No endpoint, model set, table set or seed generator was recreated.

## C. Confirmed defects and focused corrections

| Defect / cause | Correction | Primary files |
|----------------|------------|---------------|
| PostgreSQL numeric NaN compares above finite values, so `> 0` accepted it in amounts and FX rates | One corrective migration preserves positivity and explicitly excludes numeric NaN on all three columns; schema regenerated | `db/migrate/20261117120006_reject_nan_money_values.rb`, `db/schema.rb` |
| SalaryRecord numericality did not reject malformed source strings, binary Float or extra decimals before column casting | Validate the pre-cast input; reuse strict string rules and accept exact internal Integer/BigDecimal values | `app/models/salary_record.rb` |
| Direct model creation did not trim reasons; NUL reason/currency strings failed at PostgreSQL rather than returning validation errors | Normalize reason on create; validate NUL and currency syntax before querying/persisting | Model and `app/services/salary_revisions/create.rb` |
| A previously closed interval could be reopened or its end changed; model destroy could remove history | Validate immutable closed end and refuse model destroy; preserve allowed open→closed transition | `app/models/salary_record.rb` |
| Rails bigint lookup coerced paths such as `42junk` into employee42; `42.5` could parse as ID42 plus format5 | Strict decimal path ID check, with default/JSON formats only; preserve structural400 before employee404 | ApplicationController and employee/revision controllers |
| NUL query strings reached PostgreSQL and caused500 responses | Shared parser rejects them as400 invalid_parameter before SQL | `app/queries/param_parsing.rb` |
| Unexpected exception messages were logged verbatim, including credentials embedded in those messages | Log failure class and code locations without the raw exception message; generic500 response preserved | `app/controllers/concerns/api_error_handling.rb` |
| Framework environment filtering left HTTP_AUTHORIZATION visible | Add authorization to the parameter filter | `config/initializers/filter_parameter_logging.rb` |
| `CORS_ALLOWED_ORIGINS=*` enabled wildcard access despite the explicit-origin rule | Reject wildcard configuration at boot; local allow-list behavior unchanged | `config/initializers/cors.rb` |
| Seed verification ran after commit | Verify inside the generation/reset transaction, so failed verification restores previous data | `lib/seeds/demo_dataset.rb` |
| Concurrency spec used unbounded waits and lacked cleanup on failure | Bound queue/thread waits and release/clean up workers in ensure | Concurrency spec |

The new focused tests were run before fixes: **76 examples, 15 failures**, reproducing the gaps. The first full post-fix run found one remaining format-suffix case (`42.5`); that routing case was corrected before final verification. No failed check is being described as a pass.

## D. Missing backend functionality

No required MVP endpoint was missing. Remaining work was boundary enforcement and verification, now completed as described above. Added meaningful regression coverage, exact threshold10 coverage and an integration check that active-only CSV row sums reconcile to dashboard totals under matching country/department filters. Strengthened the existing full-size seed test to compare two complete generated fingerprints.

## E. Database integrity and disposable environment

Installed Ruby:4.0.9, matching `backend/.ruby-version`; Bundler4.1.0; PostgreSQL14.25. An isolated cluster was initialized at `/tmp/acme-backend-review/pgdata`, with a private Unix socket at `/tmp/acme-backend-review/socket`, port55441, and TCP disabled. `SHOW data_directory` confirmed the isolated path. All DB setup, constraints, concurrency tests and destructive seed/reset checks used this cluster; no existing user database or hosted service was touched.

Databases: `acme_backend_review_test` for RSpec; `acme_backend_review_migrations` for fresh migrations and corrective rollback/reapply; `acme_backend_review_schema` for loading the generated schema; `acme_backend_review_prepare` for fresh prepare/seed. The last three checks ran from a temporary backend copy to avoid incidental schema changes in the workspace.

Verified:

- btree_gist1.6, the scalar/tstzrange exclusion constraint and partial unique index on the local engine.
- Adjacent half-open intervals accepted; historical overlaps, a second open record and invalid interval ends rejected.
- Foreign keys, nullability, unique names/employee IDs/rate dates, code format/length, statuses, levels, termination rules, pay frequencies, positive finite money/rates and reason constraints.
- Model salary facts are readonly; a closed end cannot change through normal updates, and model destroy refuses history deletion. Deliberate raw SQL/bulk operations bypass model guards; DB triggers remain excluded by the approved design.
- The service preserves salary history, uses one timestamp for closure/insertion, rolls back failed inserts and serializes two concurrent revisions with stale-token rejection.
- Fresh migrations, correction rollback/reapply, schema load and fresh prepare produced identical normalized `pg_dump --schema-only --no-owner --no-privileges` output. The dumped schema also matched the repository `db/schema.rb` byte-for-byte. PostgreSQL also re-rendered two existing array casts equivalently during the dump; no status/frequency rule changed.
- Full seed:10,000 employees,16,055 salary records,6,055 historical records,6 countries,9 departments,4 currencies; statuses9200 active/300 on_leave/500 terminated. Full reruns matched fingerprint `040a37bf54ff252c0fd5cae2dfe83d35c975099c817f40cb820e95c2b08b882a`.

The DB guarantees at most one open record and no overlap, not that every employee has an open record or that intervals have no gaps. Service, seed and verification enforce those additional invariants. Amount upper bound and strict input precision remain application rules; numeric column capacity and positivity/finiteness are DB safeguards.

Migration caveat: existing NaN data will make the corrective CHECK validation fail. It intentionally does not delete or rewrite existing data. No user database was inspected or changed; investigate/remediate any such data deliberately before applying it there.

These results do not verify PostgreSQL17/18 or Neon. G1 remains OPEN; DR-20 hosted verification and DR-22 remain outstanding.

## F. Commands and results

Backend commands used `login=false` and the installed RVM Ruby path:

```sh
export PATH=/Users/vijaypatidar/.rvm/rubies/ruby-4.0.9/bin:/opt/homebrew/bin:$PATH
export PGHOST=/tmp/acme-backend-review/socket PGPORT=55441 RAILS_ENV=test
export DATABASE_URL=postgresql:///acme_backend_review_test
```

Local database commands ran with sandbox escalation approved for the isolated cluster, overcoming the earlier architecture audit's shared-memory/socket restrictions. No approval review rejected an action.

| Command | Result |
|---------|--------|
| `initdb -D /tmp/acme-backend-review/pgdata -A trust --no-locale -E UTF8` | Passed; new isolated cluster |
| `pg_ctl -D /tmp/acme-backend-review/pgdata -l /tmp/acme-backend-review/postgres.log -o '-k /tmp/acme-backend-review/socket -p 55441 -h ""' start` | Passed; Unix-socket-only server |
| `bin/rails db:create db:schema:load` | Passed on disposable RSpec DB |
| `bundle exec rspec --format progress` | Baseline324 examples,0 failures; seed55083 |
| `bundle exec rspec spec/models/salary_record_spec.rb spec/db/constraints_spec.rb spec/lib/seeds/demo_dataset_spec.rb spec/requests/api/v1/robustness_spec.rb spec/requests/cors_spec.rb` | Regression-before76 examples,15 failures; seed17160 |
| `bin/rails db:migrate` | Corrective migration passed on disposable RSpec DB |
| `bundle exec rspec` | Intermediate340 examples,1 remaining format-suffix failure; seed47214 |
| `FULL_SEED=1 bundle exec rspec --seed 47214` | **344 examples,0 failures**,19.35s including both full seed runs |
| `bundle check` | Passed; installed dependencies satisfied; no lockfile change |
| `bin/rubocop --cache false` | Passed after changes:82 files,0 offenses |
| `bin/rails zeitwerk:check` | Passed; all is good |
| `bundle exec brakeman --no-threads --quiet --no-pager --exit-on-warn --exit-on-error` | Passed;0 errors,0 security warnings; installed scanner, no latest-version check |
| `bundle exec bundler-audit check --no-update` | Passed; no vulnerabilities in cached advisory DB; network freshness not verified |
| `psql -XAt -d postgres -c 'SHOW data_directory'` | Confirmed `/tmp/acme-backend-review/pgdata` |
| `bin/rails db:create db:migrate`; `bin/rails db:rollback STEP=1`; `bin/rails db:migrate` | Passed in temporary copy on migration DB |
| `bin/rails db:create db:schema:load` | Passed in temporary copy on separate schema DB |
| `bin/rails db:prepare` | Passed in temporary copy on absent prepare DB; generated full demo dataset |
| `pg_dump --schema-only --no-owner --no-privileges <database>` for the three check DBs | Normalized SQL dumps identical; only random restrict/unrestrict tokens excluded |
| `pg_ctl -D /tmp/acme-backend-review/pgdata stop -m fast` | Passed after verification; disposable server stopped |
| `git diff --check` | Passed |
| `git diff --cached --check` | Existing staged error: backend/.gitignore:27 new blank line at EOF; index preserved |

RSpec emitted existing Rack deprecation warnings for the `:unprocessable_entity` symbol. The responses remain HTTP422 and the tests pass. Those unrelated aliases were not broadly rewritten. `make check`/`bin/ci` were not run because they perform broader setup/network operations; the relevant backend checks above ran individually. No frontend check or build was run in this backend-only task.

Logs and baseline snapshots are under `/tmp/acme-backend-review`. Fresh dependency installation/clean-clone reproduction, supported-major tests, production/proxy logs, hosted compatibility, deployment smoke tests, long-history performance and query-plan benchmarks were not performed.

## G. Files changed

Modified existing files (relative to this task’s entry snapshot):

- `backend/README.md`
- `backend/app/controllers/api/v1/employees_controller.rb`
- `backend/app/controllers/api/v1/salary_revisions_controller.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/app/controllers/concerns/api_error_handling.rb`
- `backend/app/models/salary_record.rb`
- `backend/app/queries/param_parsing.rb`
- `backend/app/services/salary_revisions/create.rb`
- `backend/config/initializers/cors.rb`
- `backend/config/initializers/filter_parameter_logging.rb`
- `backend/db/schema.rb`
- `backend/lib/seeds/demo_dataset.rb`
- `backend/spec/controllers/api_error_handling_spec.rb`
- `backend/spec/db/constraints_spec.rb`
- `backend/spec/lib/seeds/demo_dataset_spec.rb`
- `backend/spec/models/salary_record_spec.rb`
- `backend/spec/requests/api/v1/analytics_spec.rb`
- `backend/spec/requests/api/v1/employees_export_spec.rb`
- `backend/spec/requests/cors_spec.rb`
- `backend/spec/services/salary_revisions/concurrency_spec.rb`

Created:

- `backend/db/migrate/20261117120006_reject_nan_money_values.rb`
- `backend/spec/requests/api/v1/robustness_spec.rb`
- `docs/backend-review.md`

## H. Remaining backend tasks

| Priority | Task | Status |
|----------|------|--------|
| Done | Required local MVP APIs, calculations, revisions, reference data, export and deterministic seed | COMPLETE under reviewed local tests |
| Done | Confirmed defects and regression tests | COMPLETE |
| Done | Local migration/schema/prepare and corrective rollback/reapply checks | COMPLETE |
| Before G1 closure | Hosted role/extension/exclusion/TLS verification and owner gate review | BLOCKED: separate external verification/approval |
| Before release | Repeat backend suite on eventual supported PostgreSQL major17/18 | BLOCKED: that local/hosted engine is not available here |
| Before G5/release | DR-22 hosting/topology; actual TLS/proxy-log/CORS and release-command checks | BLOCKED: deployment decisions unresolved |
| Phase10 | Full query-plan/latency and long-history measurements | PARTIAL: implementation and correctness tests exist; benchmarks not performed |
| Separate reproduction | Clean-clone/install run-through | PARTIAL: fresh database setup verified using installed dependencies, not a new dependency installation |
| Required MVP inventory | Check for missing endpoints/workflows | COMPLETE: none missing identified in this review |

## I. Git state

Branch `main`, HEAD `5c818dc`. All prior staged/unstaged/untracked work was preserved. Files that were untracked at entry remain untracked unless separately staged by the owner; a normal `git diff` therefore omits some corrected files. Codex-only diffs were computed against the captured entry snapshot, including untracked files. The original staged index is unchanged, and requirements, architecture decision files, all frontend files, Makefile, manifests and lockfiles match their entry hashes.

## J. Confirmation

Only backend development and its documentation were changed. No frontend functionality, TypeScript or React files changed. No product scope, architecture decision, dependency or deployment implementation was added. No cloud infrastructure or hosted database was created. Local disposable database checks do not close G1 or DR-20. **G1 remains OPEN, DR-20 hosted verification remains outstanding, and DR-22 remains OPEN.** No Git reset/clean, staging, commit or push was performed. No real credentials were added; authentication strings in specs are synthetic fixtures. Phase acceptance remains an owner decision.

## Final task diff and repository status

20 existing files modified; 3 new files (including this report).

| File | Task-only line changes |
|------|------------------------|
| `backend/README.md` | +17 / −4 |
| `backend/app/controllers/api/v1/employees_controller.rb` | +1 / −1 |
| `backend/app/controllers/api/v1/salary_revisions_controller.rb` | +2 / −1 |
| `backend/app/controllers/application_controller.rb` | +11 / −0 |
| `backend/app/controllers/concerns/api_error_handling.rb` | +3 / −3 |
| `backend/app/models/salary_record.rb` | +32 / −2 |
| `backend/app/queries/param_parsing.rb` | +1 / −0 |
| `backend/app/services/salary_revisions/create.rb` | +2 / −0 |
| `backend/config/initializers/cors.rb` | +3 / −0 |
| `backend/config/initializers/filter_parameter_logging.rb` | +1 / −1 |
| `backend/db/migrate/20261117120006_reject_nan_money_values.rb` | +11 / −0 |
| `backend/db/schema.rb` | +6 / −6 |
| `backend/lib/seeds/demo_dataset.rb` | +2 / −2 |
| `backend/spec/controllers/api_error_handling_spec.rb` | +2 / −1 |
| `backend/spec/db/constraints_spec.rb` | +14 / −0 |
| `backend/spec/lib/seeds/demo_dataset_spec.rb` | +21 / −0 |
| `backend/spec/models/salary_record_spec.rb` | +38 / −0 |
| `backend/spec/requests/api/v1/analytics_spec.rb` | +2 / −2 |
| `backend/spec/requests/api/v1/employees_export_spec.rb` | +12 / −0 |
| `backend/spec/requests/api/v1/robustness_spec.rb` | +87 / −0 |
| `backend/spec/requests/cors_spec.rb` | +10 / −0 |
| `backend/spec/services/salary_revisions/concurrency_spec.rb` | +9 / −1 |
| `docs/backend-review.md` | New report |

```text
A  .editorconfig
AM .github/copilot-instructions.md
A  .github/prompts/architecture-phase.prompt.md
A  .gitignore
A  Makefile
AM README.md
AM backend/.env.example
A  backend/.gitattributes
A  backend/.gitignore
A  backend/.rspec
A  backend/.rubocop.yml
A  backend/.ruby-version
A  backend/Gemfile
A  backend/Gemfile.lock
AM backend/README.md
A  backend/Rakefile
AM backend/app/controllers/application_controller.rb
A  backend/app/controllers/concerns/.keep
AM backend/app/controllers/concerns/api_error_handling.rb
A  backend/app/models/application_record.rb
A  backend/app/models/concerns/.keep
A  backend/bin/brakeman
A  backend/bin/bundler-audit
A  backend/bin/ci
A  backend/bin/dev
A  backend/bin/rails
A  backend/bin/rake
A  backend/bin/rubocop
A  backend/bin/setup
A  backend/config.ru
A  backend/config/application.rb
A  backend/config/boot.rb
A  backend/config/bundler-audit.yml
A  backend/config/ci.rb
A  backend/config/credentials.yml.enc
A  backend/config/database.yml
A  backend/config/environment.rb
A  backend/config/environments/development.rb
A  backend/config/environments/production.rb
A  backend/config/environments/test.rb
AM backend/config/initializers/cors.rb
AM backend/config/initializers/filter_parameter_logging.rb
A  backend/config/initializers/inflections.rb
A  backend/config/locales/en.yml
A  backend/config/puma.rb
AM backend/config/routes.rb
AM backend/db/seeds.rb
A  backend/lib/tasks/.keep
A  backend/log/.keep
A  backend/script/.keep
AM backend/spec/controllers/api_error_handling_spec.rb
AM backend/spec/rails_helper.rb
AM backend/spec/requests/cors_spec.rb
A  backend/spec/requests/health_spec.rb
A  backend/spec/requests/unknown_routes_spec.rb
AM backend/spec/spec_helper.rb
A  backend/tmp/.keep
A  backend/tmp/pids/.keep
A  backend/vendor/.keep
MM docs/api-contracts.md
MM docs/architecture-review.md
MM docs/architecture.md
MM docs/domain-decisions.md
MM docs/implementation-plan.md
A  frontend/.env.example
A  frontend/.gitignore
AM frontend/README.md
A  frontend/eslint.config.js
A  frontend/index.html
A  frontend/package-lock.json
A  frontend/package.json
A  frontend/public/favicon.svg
A  frontend/src/app/App.tsx
A  frontend/src/app/router.test.tsx
A  frontend/src/app/router.tsx
A  frontend/src/components/common/NotFoundPage.tsx
A  frontend/src/components/layout/AppLayout.tsx
A  frontend/src/components/ui/.gitkeep
A  frontend/src/features/compensation/.gitkeep
A  frontend/src/features/dashboard/.gitkeep
A  frontend/src/features/employees/.gitkeep
A  frontend/src/features/health/StatusPage.test.tsx
A  frontend/src/features/health/StatusPage.tsx
A  frontend/src/features/health/health.ts
A  frontend/src/features/health/useApiHealth.ts
A  frontend/src/features/salary-revisions/.gitkeep
A  frontend/src/lib/api.ts
A  frontend/src/lib/query-client.ts
A  frontend/src/main.tsx
A  frontend/src/styles/index.css
A  frontend/src/test/renderRoute.tsx
A  frontend/src/test/setup.ts
A  frontend/src/types/env.d.ts
A  frontend/tsconfig.app.json
A  frontend/tsconfig.json
A  frontend/tsconfig.node.json
A  frontend/vite.config.ts
?? backend/app/controllers/api/
?? backend/app/controllers/concerns/write_key_authentication.rb
?? backend/app/errors/
?? backend/app/models/compensation.rb
?? backend/app/models/country.rb
?? backend/app/models/currency.rb
?? backend/app/models/decimal_string.rb
?? backend/app/models/department.rb
?? backend/app/models/employee.rb
?? backend/app/models/exchange_rate.rb
?? backend/app/models/salary_amount.rb
?? backend/app/models/salary_record.rb
?? backend/app/queries/
?? backend/app/serializers/
?? backend/app/services/
?? backend/db/migrate/
?? backend/db/schema.rb
?? backend/lib/seeds/
?? backend/spec/db/
?? backend/spec/factories/
?? backend/spec/lib/
?? backend/spec/models/
?? backend/spec/queries/
?? backend/spec/requests/api/
?? backend/spec/services/
?? backend/spec/support/
?? docs/audit-report.md
?? docs/backend-review.md
```
