# Architecture audit report — 17 November 2026

This audit covers documentation, architecture decisions, dependency consistency and G1 evidence. **G1 remains OPEN.** No implementation phase is authorized by this report. Existing uncommitted application work was preserved.

## A. Prior Copilot progress

Git establishes file states, not the author of uncommitted work. “Prior work” below means work present before Codex began; attributing every staged or unstaged change to Copilot would be unsupported. HEAD at entry was `5c818dc`; the only existing commits are the original requirements and architecture documentation commits.

| Task | Existing state found | Classification at entry | Codex action |
|------|----------------------|-------------------------|--------------|
| DR-05 | Delegated approval, snapshot precision/direction/lookup and affected domain/schema/API docs already recorded | COMPLETE | Preserved selected design; separated owner sign-off from decision completion |
| DR-09 | Delegated approval, open last-salary-held record and termination CHECK already recorded | COMPLETE | Preserved; clarified API meaning for terminated employees |
| DR-12 | Delegated approval, required trimmed free text and varchar(255)/non-blank CHECK documented | COMPLETE | Preserved; no reason table introduced |
| DR-14 | Delegated approval, currencies table and reference_data retained consistently | COMPLETE | Preserved; optional enhancement remains distinct from assessment requirement |
| DR-20 selection | Neon Free chosen; six-provider documentary comparison; local spike and hosted probe documented | PARTIAL | Rechecked official Neon docs, retained selection, improved role/TLS/migration evidence and probe; runtime remains BLOCKED |
| Dependency cleanup | pagy, faker, lucide-react absent from manifests/locks; Tailwind 4, rack-cors, router present and used | COMPLETE | Verified; no removal, installation, upgrade or lockfile edit |
| Other low-risk decisions | Recommended defaults still marked approval-required despite being specified across documents | PARTIAL | Recorded current delegated decisions for DR-02,06,07,08,10,13,15,16,17,18,19,23 |
| Documentation consistency | Register/plan/API/architecture said scaffold only, while unstaged/untracked backend features existed; stale approval references and CORS instructions | INCORRECT | Corrected present state and statuses, kept historical verification clearly historical |
| G1 assessment | Correctly open for hosted test/sign-off, but readiness rows asserted PASS for a prior tree | PARTIAL | Rebuilt evidence checklist; fresh setup NOT TESTED; database checks BLOCKED |
| Application host/deployment | DR-22 open; no deployment configuration | BLOCKED | Preserved; missing host, budget/region and topology evidence |
| Backend features beyond scaffold | Existing migrations, models, endpoints, seed and feature specs span Phases 3–7 | PARTIAL / unverified | Preserved byte-for-byte; no acceptance inferred and no features added |

## B. Architecture decisions

O = existing recorded owner approval; D = approved under delegation, owner gate review pending. Existing approval records were reviewed, not independently authenticated from original owner conversations.

| ID | Final status | Selected approach and rationale | Remaining action |
|----|--------------|---------------------------------|------------------|
| DR-01 | O, preserved | Server UTC timestamptz, one microsecond-normalized instant after lock; increasing same-day revisions | Supported-major/runtime tests |
| DR-02 | D, decided here | Shared demo write key, fail closed, client memory only; no accounts | Owner G3 review; production secret/log/TLS checks |
| DR-03 | O, preserved | active/on_leave/terminated; only active totals; on_leave revisable | Runtime eligibility checks |
| DR-04 | O, preserved | Mandatory current-record token + employee lock; prevents stale overwrite | Runtime concurrency checks |
| DR-05 | D, preserved | Snapshot fx_rate numeric(18,8), latest rate ≤ effective UTC date; no default 1 | Owner G1 sign-off |
| DR-06 | D, decided here | Annualize, convert, round each row once; aggregate rounded numeric values | Owner G2 review; parity/reconciliation tests |
| DR-07 | D, decided here | Currency independent of country; no invented pairing restriction | Owner G2 review |
| DR-08 | D, decided here | Low sample <10 active, constant exposed by reference_data | Owner G4 review; UI flag verification |
| DR-09 | D, preserved | Terminated last salary stays open; termination-date consistency CHECK | Owner G1 sign-off |
| DR-10 | D, decided here | Reject unchanged amount/currency/frequency, including reason-only edits | Owner G2 review |
| DR-11 | O, preserved | Entered local-period amount ≤1000000000.00; strict decimal string; application bound | Runtime input tests |
| DR-12 | D, preserved | Required trimmed 1–255-character free text, including seed records | Owner G1 sign-off |
| DR-13 | D, decided here | Current-state grouping; no employee transfer history | Owner G4 review |
| DR-14 | D, preserved | Keep currencies table and reference_data; FK integrity and UI option source | Owner G1 sign-off; endpoint acceptance later |
| DR-15 | D, decided here | Exact numeric middle/mean-of-two median, output rounding; no percentile_cont | Owner G4 review; median tests |
| DR-16 | D, decided here | Country/department/level filters, country local_totals, filtered all-status counts | Owner G4 review |
| DR-17 | D, decided here | Existing fixed RNG/anchor/curated generator parameters, illustrative rates and exactly 10,000 employees | Owner G4 review; two-run/invariant verification |
| DR-18 | D, decided here | Numeric IDs, UTC display, page 25/max100, existing allow-list | Owner G3 review |
| DR-19 | D, decided here | Full newest-first unpaginated history; explicit growth trade-off | Owner G3 review; Phase 10 long-history measurement |
| DR-20 | Design O; provider D; runtime BLOCKED | Preserve Neon Free, direct connection; supported PG17 or 18 | Hosted role/extension/constraint/Rails probe and owner G1 sign-off |
| DR-21 | O, preserved | schema.rb, varchar codes + CHECKs; recorded local round trip | Fresh current-schema round trip, supported PostgreSQL major |
| DR-22 | OPEN / BLOCKED | Two deployables + managed DB remains recommendation; app host/topology/production CORS undetermined | Host, region, budget and release-command decision before G5 |
| DR-23 | D, decided here | No application throttling dependency; platform limits if available, otherwise documented demo risk | Owner G3 review; deployment policy after DR-22 |
| DR-24 | O, preserved | Approved baseline, Tailwind4/router/rack-cors; unnecessary dependencies already absent | Owner confirmation of generator-tooling interpretation with G0 review |

For the original five decisions, alternatives and evidence were checked against the original HEAD register and current staged register:

| Decision | Original alternatives | Support and consistency |
|----------|-----------------------|-------------------------|
| DR-05 | Copy rate vs FK to immutable exchange-rate row; mutable rate on country rejected | Requirements explicitly retain conversion rate used; snapshot removes join/edit dependency. Domain §3.3, architecture §4.5/4.6, API salary fields and plan align |
| DR-09 | Keep last record open vs close it at termination | Preserves one-open-record invariant without lifecycle workflow; active-only totals/eligibility remain separate. Domain §5/8 and schema/API rules align |
| DR-12 | Free text vs controlled vocabulary/reason lookup | Required reason/history in brief; no reporting-by-reason requirement. Domain §5, architecture §4.5 and API request agree |
| DR-14 | Table+endpoint vs CHECK/constants+frontend lists | Existing six-table design, FK currency integrity and DB department IDs justify the retained option. Schema, API §6 and plan align |
| DR-20 | Hosted PostgreSQL providers vs explicitly approved weaker integrity fallback | Local evidence does not prove hosted support. Neon official docs justify selection, not runtime PASS. No weaker fallback approved |

## C. Hosted PostgreSQL

**Neon Free remains selected; actual hosted compatibility is unverified.** Official sources accessed in this audit:

- [Extensions](https://neon.com/docs/extensions/pg-extensions): btree_gist listed across PG14–18, including 1.7 on PG17 and 1.8 on PG18. Choose a supported major (17 or 18), not the local PG14 baseline.
- [btree_gist](https://neon.com/docs/extensions/btree_gist): documents enabling the extension and scalar-plus-tstzrange exclusion constraints. This supports the intended employee/range design; no hosted test was performed.
- [Roles](https://neon.com/docs/manage/roles): Console/API administrator roles differ from minimal SQL-created roles. The actual migration role's extension privileges still need verification.
- [Rails integration](https://neon.com/docs/guides/ruby-on-rails): standard PostgreSQL URL with TLS. Export the explicit hosted database URL in the backend environment; optional dotenv in the guide is unnecessary here.
- [Pooling](https://neon.com/docs/connect/connection-pooling): direct migration connections avoid session-feature restrictions. Preserve one direct URL for this small app. Transaction-scoped row locks are not session advisory locks; pooling does not inherently invalidate them ([PostgreSQL locking](https://www.postgresql.org/docs/current/explicit-locking.html)).
- [Plans](https://neon.com/docs/introduction/plans): $0 Free; 1 GB/project, 100 CU-hours/project, 5 GB public transfer, mandatory five-minute idle suspend as documented when accessed. Capacity, cold-start latency and seed runtime were not measured; limits/card requirements must be rechecked at provisioning. Free service is not evidence of production availability.

The previous six-provider comparison is preserved as historical evidence, not a newly verified exhaustive comparison. No provider switch is justified. Rails migrations and a one-off seed through a direct TLS URL are technically feasible by inference from the documented PostgreSQL connection model; execution, role privileges, schema round trip and deterministic seed results on Neon remain untested. DR-22 must specify where release and seed commands run and where server secrets are configured. No cloud account, project or database was created.

The local spike (§12.1) is a historical report of PostgreSQL14.25, extension1.6, 11 passing probes and schema round-trip behavior. It was not independently reproduced here. The improved hosted probe is session-local, uses UTC literals and catches the expected overlap error so cleanup works in a single SQL-editor transaction. It has not been executed here.

## D. Codex file changes

Only these existing text files were changed:

1. `docs/architecture-review.md` — decision records, evidence limits, CORS/pooling corrections, hosted probe.
2. `docs/domain-decisions.md` — propagated delegated statuses; clock-conflict and history-generation wording.
3. `docs/architecture.md` — current repository state, delegated references, direct-connection rationale.
4. `docs/api-contracts.md` — current endpoint-code state, delegated statuses, terminated salary meaning.
5. `docs/implementation-plan.md` — evidence-based G1 checklist, historical vs current verification, unchanged gate boundary.
6. `.github/copilot-instructions.md` — current approvals and implementation hold.
7. `README.md` — remove unqualified tested claim; link audit and state G1 open.
8. `backend/README.md` — current decisions/verification limits; remove unsubstantiated seed timing and absolute CSV-safety claim.
9. `frontend/README.md` — DR-02 status reference.

New documentation: `docs/audit-report.md` (this report). Requirements, manifests, lockfiles, Makefile, application source, migrations, schema and tests were not changed. The original staged index is byte-for-byte unchanged. Initial staged/unstaged diffs and file hashes were captured under `/tmp/acme-architecture-audit`; Codex-only diffs are measured against that baseline, not against HEAD.

## E. Dependencies

| Dependency | Audit result | Action |
|------------|--------------|--------|
| pagy | Already absent in Gemfile/lockfile | None; direct contract pagination retained |
| faker | Already absent | None; curated deterministic names retained |
| lucide-react | Already absent in npm manifest/lock | None |
| Tailwind CSS4 and Vite plugin | Present; imported/configured | Retained, DR-24 |
| rack-cors | Present; initializer and CORS specs | Retained for local development; production configuration remains DR-22 |
| react-router-dom7 | Present; app router and tests use it | Retained, DR-24 |
| TanStack Query | Present; query client/health hook use it | Retained, DR-24 |
| FactoryBot and scaffold tools | Existing baseline/plan tooling | Preserved; G0 interpretation review remains recorded |

No dependencies were removed or installed in this audit, no lockfiles changed, and none require further cleanup. npm manifest root declarations match package-lock; `bundle check` reports dependencies satisfied.

## F. Unresolved items and topic review

| Topic | Disposition |
|-------|-------------|
| Revision timestamp and same-day changes | DR-01 preserved; strictly increasing microseconds. Row lock does not make wall-clock monotonic; reject non-increasing time |
| Amount maximum/precision | DR-11 preserved; local-period bound, numeric(14,2), strict decimal strings; reject >2 decimals before PostgreSQL can round |
| Status/revision eligibility | DR-03/09 preserved; on_leave revisable, only active in totals, terminated last salary held |
| Stale revision handling | DR-04 preserved; mandatory token plus employee lock |
| Low sample | DR-08 decided; <10 active, no statistical inference |
| Demo protection | DR-02/23 decided; no extra authentication/infrastructure; deployment checks still required |
| FX | DR-05 preserved; direction, snapshot, precision and UTC lookup align; DR-06 rounding decided |
| History integrity | Exclusion constraint for overlaps; partial index for ≤1 open; service/seed for ≥1 and no gaps |
| Schema/extensions | DR-20/21 retained; local historical spike only; hosted verification open |
| Deployment/CORS | DR-22 remains open; reuse existing rack-cors if needed, no new gem approval loop |
| Dependencies/routing | Already reconciled; no new dependencies |
| Assessment vs enhancements | currencies/reference_data retained as approved enhancements; analytics extras support brief; no new assessment requirement invented |

Remaining owner actions: whole-document G0 approval/tooling interpretation; G1 sign-off after hosted evidence; later G2–G4 gate review of delegated decisions; DR-22/G5. Requirements wording proposals (§9) are optional clarifications, not product contradictions or G1 blockers; `docs/requirements.md` was preserved. Assessment PDF publication is optional and defaults to not publishing.

Remaining verification: supported-major local database compatibility; RSpec/constraint/concurrency specs; current-tree fresh setup and schema load/prepare; hosted role/extension/constraint/TLS probe; hosted migrations and deterministic 10,000-employee seed; deployment smoke tests; Phase10 performance and long-history measurements. No TBD business rule was invented. Historical approval markers in conflict history and the saved architecture prompt are preserved as history. Future implementation/testing tasks remain valid; no marker alone was treated as a blocker.

There is also a stale generated comment in `backend/config/database.yml` saying provider selection is pending, while the actual unresolved issue is hosted verification. Configuration behavior was preserved; the authoritative provider decision is DR-20. Existing code comments calling defaults approval-pending may likewise predate this audit; they are not new decision records. The backend feature work needs separate phase acceptance review; passing static checks is insufficient.

## G. G1 checklist

The complete checklist and supporting next actions are in `implementation-plan.md`, “G1 checklist (Codex audit, 17 November 2026)”. The original gate requires DR-01,03,05,09,11,12,14,20,21 plus explicit owner approval. It is not replaced by generic scaffold success.

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

## H. Checks executed

Backend commands were run from `backend/`. The first backend attempt through the login shell selected system Ruby2.6, so those failures were corrected by using `login=false` and this explicit PATH; no runtime or package was installed:

```sh
export PATH=/Users/vijaypatidar/.rvm/rubies/ruby-4.0.9/bin:/opt/homebrew/bin:$PATH
```

| Exact command | Actual result |
|---------------|---------------|
| `ruby -v`; `bundle -v`; `node -v`; `npm -v`; `psql --version` | Ruby4.0.9, Bundler4.1.0, Node26.13.1, npm12.2.2, PostgreSQL client14.25 |
| `pg_isready` | Exit2, `/tmp:5432 - no response` |
| Initial `bundle check`; `bin/rubocop --cache false`; `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | Wrong login-shell Ruby; missing Bundler4.1.0 / unsupported windows platform under system Ruby2.6; not project-version failures |
| `bundle check` with explicit PATH | Exit0; dependencies satisfied |
| `bin/rubocop --cache false` with explicit PATH | Exit0; 80 files inspected, no offenses |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` with explicit PATH | Exit1; wrapper forces latest-version check, cache write denied under ~/.gem; no successful scan claimed for this command |
| `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | Exit0, zero warnings, but worker/temp-home cleanup diagnostics; repeated sequentially below |
| `bundle exec brakeman --no-threads --quiet --no-pager --exit-on-warn --exit-on-error` | Exit0; Errors0, Security Warnings0; installed scanner only, no latest-version assertion |
| `bin/rails zeitwerk:check` | Exit0; eager loading: All is good |
| `bundle exec bundler-audit check --no-update` | Exit0; no vulnerabilities in cached advisory database; network freshness not established |
| `bundle exec rspec` | Exit1; 0 examples, 22 errors outside examples. PG::ConnectionBad, local socket Operation not permitted. Does not verify application behavior |
| `make frontend-check` (root) | Exit0: typecheck, ESLint, Vitest 2 files/5 tests passed, Vite production build succeeded |
| `initdb -D /tmp/acme-architecture-audit/pgdata -A trust --no-locale -E UTF8` | Exit1: could not create shared memory segment, Operation not permitted; initdb removed its partial directory |
| `mkdir -p /tmp/acme-architecture-audit/socket` | Temporary local check directory created |
| `pg_ctl -D /tmp/acme-architecture-audit/pgdata -l /tmp/acme-architecture-audit/postgres.log -o '-k /tmp/acme-architecture-audit/socket -p 55439 -h ""' start` | Exit1; data directory absent after failed initdb; no server started |
| Python manifest comparison (standard library json/re) | pagy/faker/lucide-react absent in all four manifest/lock files; npm dependencies/devDependencies equal lockfile root declarations |
| `git diff --check` | Exit0; unstaged changes clean |
| `git diff --cached --check` | Exit2; pre-existing staged backend/.gitignore:27 new blank line at EOF; index deliberately preserved |

RSpec output was redirected to `/tmp/acme-architecture-audit/rspec.log`; sequential Brakeman output to `brakeman.log` there. `make check` and `make backend-check` were not run: backend CI invokes setup, database prepare, log clearing and a network audit; individual safe checks above give more precise evidence. No install, seed, reset or migration command was run against the user's database. Clean-clone/clean-install reproduction, live health/browser check, Mermaid rendering and link reachability beyond the official pages visited were not tested.

Read-only audit commands included `git branch --show-current`, `git status --short`, `git diff`, `git diff --cached`, `git diff --stat`, `git diff --cached --stat`, `git log -5 --oneline`, `git show HEAD:docs/architecture-review.md`, `rg --files --hidden` with generated-directory exclusions, full-file/chunked `cat`/`sed` reads of all original docs and relevant config/manifests, and `rg -n` searches for approval/TODO/TBD/open/blocked/pending markers. Initial full diffs were captured despite console truncation. Hash and Codex-only diff validation compare the final files with the captured initial tree, including untracked backend work.

## I. Git state

Branch: **main**. Nothing was staged, unstaged, reset, cleaned, committed or pushed by Codex. Existing staged work remains staged, existing unstaged work remains, and existing untracked backend features remain untracked. Full final status and a Codex-only diff summary follow; counts include prior work and must not be attributed entirely to this audit.

## J. Conclusion

Prior work had already resolved the four requested delegated decisions, selected Neon on documentary evidence, cleaned the three unnecessary dependencies and recorded a local spike. Codex preserved those choices, decided the remaining reasonable MVP defaults under the current delegation, reconciled documentation/current state, rechecked official Neon evidence and rebuilt the G1 checklist from actual check outcomes.

The architecture is ready for owner review with explicit limitations; it is not fully approved or operationally verified. Hosted verification, owner sign-off, DR-22 and current database/setup acceptance remain outstanding. Phase3 cannot be authorized solely by reviewing this report: the original hosted check and sign-off must pass first. Pre-existing Phase3–7 backend work must be reviewed for acceptance separately before implementation resumes.

**Codex did not start Phase3 or implement any application feature.** Phase3 artifacts already existed at entry, so it would be false to claim the repository has never entered that work. No cloud infrastructure, account or database was created. No dependencies were installed. Nothing was committed or pushed. Work stops for owner review.

## Final repository snapshot

Codex-only summary against the captured entry state:

| File | Lines added / removed |
|------|-----------------------|
| `.github/copilot-instructions.md` | +5 / −4 |
| `README.md` | +5 / −4 |
| `backend/README.md` | +10 / −6 |
| `docs/api-contracts.md` | +7 / −7 |
| `docs/architecture-review.md` | +81 / −45 |
| `docs/architecture.md` | +9 / −9 |
| `docs/domain-decisions.md` | +21 / −21 |
| `docs/implementation-plan.md` | +35 / −32 |
| `frontend/README.md` | +1 / −1 |
| `docs/audit-report.md` | New report |

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
A  backend/app/controllers/application_controller.rb
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
A  backend/config/initializers/cors.rb
A  backend/config/initializers/filter_parameter_logging.rb
A  backend/config/initializers/inflections.rb
A  backend/config/locales/en.yml
A  backend/config/puma.rb
AM backend/config/routes.rb
AM backend/db/seeds.rb
A  backend/lib/tasks/.keep
A  backend/log/.keep
A  backend/script/.keep
A  backend/spec/controllers/api_error_handling_spec.rb
AM backend/spec/rails_helper.rb
A  backend/spec/requests/cors_spec.rb
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
```

Validation: all 24 register headings present; only DR-22 retains an unresolved technical-selection marker; DR-20 retains hosted PENDING. Relative Markdown file links resolve. Hash comparison confirms all pre-existing application, config, migration, schema, spec, requirements and dependency files are unchanged; the staged index is unchanged. Mermaid diagrams were preserved but not rendered.
