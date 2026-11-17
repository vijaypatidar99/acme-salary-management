# One-time Neon production seeding

This workflow is prepared for `vijaypatidar99/acme-salary-management`, the existing Render API and
Cloudflare Pages frontend. Deployment URLs are context supplied by the owner, not newly verified
by this task. The owner reports Neon PostgreSQL 18 / `neondb` has already been migrated and its
extension/exclusion constraint verified. The workflow rechecks those conditions before any insert.
It never creates, migrates, drops, truncates or resets a database. It does not change gate approvals.

## Required repository secrets

In GitHub → repository **Settings → Secrets and variables → Actions → New repository secret**, set:

| Secret | Required value |
|---|---|
| `NEON_DATABASE_URL` | Actual credential-bearing **direct** Neon PostgreSQL connection URL for `neondb`; retain an explicit `sslmode=require` or `sslmode=verify-full`. Copy it privately from the correct Neon branch/role. Do not use a pooled endpoint. |
| `NEON_EXPECTED_HOST` | Independently confirm the exact direct endpoint hostname in the intended Neon project's Connect dialog, ending in `.neon.tech`. Hostname only, no scheme/port/path. It must exactly match the URL hostname. The task did not supply this hostname; it cannot be guessed from the public app URLs. |
| `SECRET_KEY_BASE` | The actual authorized Rails production boot secret, normally the existing Render backend's `SECRET_KEY_BASE`. Do not invent a value in YAML or paste a secret into logs, code, screenshots or chat. |

The inspected Rails configuration does not set `require_master_key` or read custom encrypted
credentials for this task. With `SECRET_KEY_BASE` supplied, no `RAILS_MASTER_KEY` is required by the
current seed path. If production boot is later changed to require encrypted credentials, supply the
real matching master key securely and update this workflow deliberately. Do not generate a dummy
key to bypass boot. `DEMO_WRITE_KEY` is unnecessary here: the existing Rails task writes directly to
PostgreSQL, not through the protected HTTP endpoint. No frontend `VITE_*` secret is used.

Use the direct URL with credentials properly URL-encoded. Only `sslmode`, `channel_binding`,
`connect_timeout` and `sslrootcert` query options are accepted; duplicates and hidden host/service
or search-path overrides are refused. `verify-full` is preferable when configured with a trusted
CA; `require` enforces encryption but does not provide the same hostname verification assurance.
The live connection must also report TLS in `pg_stat_ssl`.
[Neon secure connections](https://neon.com/docs/connect/connect-securely).

## Trigger exactly once

1. Review the workflow, helper and tests. **The owner** must commit/push these files to `main`;
   nothing is committed or pushed automatically by this task. Ensure Actions is enabled.
2. Add the three secrets above. Confirm the endpoint/branch is the intended production database,
   and no application/reference data has already been inserted. Pause other administrative writes
   during the run. Do not enable step debug tracing or add `set -x`/environment dumps.
3. Open `https://github.com/vijaypatidar99/acme-salary-management/actions`.
4. Select **Seed Neon (one-time, empty database only)** → **Run workflow** → choose **main**.
5. Type **`SEED_NEON_10000`** exactly in `confirmation`, then click **Run workflow**.
6. Open the run and wait for the final success message. It reports verified counts only after commit.
   Record the run URL/SHA privately or in the deployment evidence, without credentials.
7. Check the deployed dashboard/directory read-only and run the SQL below in Neon's SQL Editor.
   Do not trigger a second seed to test idempotency: this workflow intentionally refuses any nonempty
   application table, even though the underlying generator has a safe no-op mode.

Only `workflow_dispatch` can trigger the workflow; pushes, pull requests and schedules cannot.
Execution is restricted to this repository and `main`. The static concurrency group queues runs
rather than canceling an active seed. A queued/manual rerun must still pass the empty checks.
[GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).

## What executes

The Ubuntu 24.04 hosted job reads Ruby from `backend/.ruby-version` (currently `ruby-4.0.9`).
`ruby/setup-ruby` with `working-directory: backend` uses the lockfile's Bundler (currently 4.1.0),
installs/caches locked gems and runs with a frozen lockfile, excluding development/test groups.
Production secrets are scoped to validation/seed steps, not dependency installation.
[Official setup-ruby behavior](https://github.com/ruby/setup-ruby#working-directory).

The workflow runs, from `backend/`:

```sh
# Required secrets and confirmation are injected through the step environment, never command text.
RAILS_ENV=production ALLOW_PRODUCTION_SEED=1 bundle exec ruby script/seed_neon.rb
```

The helper invokes the **existing** `Rake::Task['db:seed']` in process, equivalent to the documented
`RAILS_ENV=production ALLOW_PRODUCTION_SEED=1 bin/rails db:seed`. This preserves the existing
production guard/generator/verification and lets the task share the locking transaction. It does
not replace `db/seeds.rb` or duplicate the generator. Never run the bare task as a fallback around a
failed preflight.

Sequence:

- Validate exact confirmation, required secrets, production opt-in, direct hostname/`neondb`, TLS
  URL policy and absence of destructive/inherited connection flags **before Rails boot**.
- Boot Rails with raw driver/Rails output suppressed. Errors/backtraces can contain credentials;
  the helper emits only static refusal messages or a safe failure phase. No raw exception is logged.
- In an actual **read-only transaction**, verify database/schema/host, TLS, PostgreSQL 18, all six
  public application tables, `btree_gist`, validated salary exclusion and constraint validity.
  Require **all six tables** empty, including employees and salaries. Partial reference data is
  refused rather than overwritten.
- Start one outer transaction, acquire a nonblocking advisory lock and table write locks, then
  repeat the checks. This closes the preflight/seed race and rejects competing writes immediately.
  Reads can continue; application writes can block while these locks are held.
- Invoke the existing seed task **once**, with `ALLOW_PRODUCTION_SEED=1` and `RESET` empty. Original
  pending-migration checks remain active; no migration is executed automatically.
- Call `Seeds::DemoDataset.new.verify!`, which already checks employee count, exactly one open
  record, no overlaps/gaps, hire/termination ordering, reasons, status consistency and FX snapshots.
  Also require 10000 employees, 16055 salaries, 6055 historical records, 10000 open salaries,
  6 countries, 9 departments, 4 currencies, 4 FX rows and the expected 9200/300/500 statuses.
- Commit only if every check succeeds. A verification error rolls back the seed transaction.
  There is no automatic retry, reset, schema recreation or recovery branch.

Both GitHub concurrency and the database locks are used: GitHub's group controls this workflow,
while the DB locks protect the actual data against another cooperating seed/API write. The helper
assumes this repository's single primary database configuration and synchronous seed; changing to
multiple DBs or asynchronous writes requires a new review of transaction/connection scope.

## Read-only verification queries

Run after a successful workflow in the correct Neon SQL Editor connection. Expected values are
shown in comments. These queries never expose the URL or credentials.

```sql
BEGIN READ ONLY;
SELECT current_database(), current_schema(), current_setting('server_version');
SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid(); -- true
SELECT
  (SELECT count(*) FROM employees) AS employees,           -- 10000
  (SELECT count(*) FROM salary_records) AS salaries,       -- 16055
  (SELECT count(*) FROM salary_records WHERE effective_to IS NULL) AS open_records, -- 10000
  (SELECT count(*) FROM salary_records WHERE effective_to IS NOT NULL) AS history;  -- 6055
SELECT employment_status, count(*) FROM employees GROUP BY employment_status;
-- active 9200, on_leave 300, terminated 500
SELECT
  (SELECT count(*) FROM countries) AS countries,           -- 6
  (SELECT count(*) FROM departments) AS departments,       -- 9
  (SELECT count(*) FROM currencies) AS currencies,         -- 4
  (SELECT count(*) FROM exchange_rates) AS exchange_rates; -- 4
SELECT count(*) AS invalid_open_records FROM employees e
WHERE (SELECT count(*) FROM salary_records s
       WHERE s.employee_id = e.id AND s.effective_to IS NULL) <> 1; -- 0
SELECT count(*) AS overlaps FROM salary_records a JOIN salary_records b
  ON a.employee_id = b.employee_id AND a.id < b.id
 AND tstzrange(a.effective_from, a.effective_to, '[)') &&
     tstzrange(b.effective_from, b.effective_to, '[)'); -- 0
SELECT count(*) AS gaps FROM (
  SELECT effective_from,
         lag(effective_to) OVER (PARTITION BY employee_id ORDER BY effective_from) AS previous_to
  FROM salary_records
) h WHERE previous_to IS NOT NULL AND previous_to <> effective_from; -- 0
SELECT count(*) AS incorrect_fx FROM salary_records s WHERE s.fx_rate IS DISTINCT FROM (
  SELECT r.rate FROM exchange_rates r
  WHERE r.from_currency=s.currency_code AND r.to_currency='USD'
    AND r.effective_on <= (s.effective_from AT TIME ZONE 'UTC')::date
  ORDER BY r.effective_on DESC LIMIT 1
); -- 0
ROLLBACK;
```

## Failures and limitations

- **No production connection or seed was attempted during implementation.** Offline checks validate
  configuration/refusal paths and workflow structure; they do not prove runner Ruby availability,
  production boot, Neon permissions/connectivity/TLS or successful seeding. The first authorized
  manual run is still required. No success for the hosted seed is claimed here.
- The URL and exact expected hostname must be configured by the owner; the hostname was not supplied
  in the request. Missing secrets fail before dependency installation and are rechecked before boot.
- The Neon role needs CONNECT, table/sequence write access and the locks used here. The schema must
  already be migrated and empty. Inaccessible targets, missing tables, unvalidated constraints,
  pending migrations or insufficient privileges stop the job without repair attempts.
- The job has a 45-minute cap. The existing generator performs one FX lookup per salary row; remote
  latency can affect runtime. No seed optimization or hosted runtime guarantee is introduced.
- If cancellation, timeout, disconnect or an ambiguous commit failure occurs, inspect counts and
  invariants **read-only** before deciding what happened. Do not assume failure means zero data;
  never automatically rerun or set RESET. Sequences can advance even if a transaction rolls back;
  the generator uses explicit deterministic IDs and resets its own sequence positions normally.
- The transaction also verifies before commit, so corruption/count failures cannot intentionally
  leave a partly seeded dataset. Already committed data makes subsequent attempts fail empty checks.
- Workflow/job output contains only safe phases/counts; low-level errors are intentionally withheld.
  Investigate connection/role/configuration privately without printing credentials or disabling the
  guards. Review third-party action versions and the selected Git commit before dispatch.

## Offline checks performed

- Ruby syntax for the helper: PASS.
- Six database-free RSpec examples: PASS (configuration, target/TLS rejection, all-table empty checks,
  SELECT/SHOW-only preflight, offline subprocess mode and credential-safe errors).
- RuboCop on both new Ruby files: 2 files, 0 offenses.
- YAML parsing/static policy assertions and Bash syntax: PASS. Dispatch-only input, repository/main
  restriction, read-only permissions, concurrency, production environment, lockfile/Ruby source and
  absence of seed retries checked. `actionlint` is not installed and was not claimed to run.
- No application features, salary rules, seed logic, migrations, dependency manifests or lockfiles
  changed. No production seed, GitHub dispatch, commit or push performed.
