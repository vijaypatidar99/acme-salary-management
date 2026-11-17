# ACME Salary Management

Web app for an ACME HR Manager to find employee compensation records, revise base salaries
without losing history, and see how base pay is distributed across 10,000 synthetic employees.

**Status: backend and frontend MVP implemented and locally verified.** The React app now includes
compensation analytics, employee search/filter/pagination, profiles and salary history, protected
salary revisions and CSV export, connected to the Rails API. The frontend check passes 55 tests;
actual local browser workflows were verified on a disposable 10,000-employee database.
See the [frontend review](docs/frontend-review.md) and [backend review](docs/backend-review.md).
**G1 remains OPEN**: hosted DR-20 verification and owner gate sign-off remain outstanding;
application hosting and production CORS remain DR-22.
Scope, rules and phases are in [`docs/`](docs):
start with [`requirements.md`](docs/requirements.md) and
[`implementation-plan.md`](docs/implementation-plan.md). Decisions still awaiting the owner are
in the register, [`architecture-review.md`](docs/architecture-review.md) §3.

| Directory | Contents |
|-----------|----------|
| [`backend/`](backend) | Rails 8.1 API-only app, PostgreSQL, RSpec — see its README |
| [`frontend/`](frontend) | React 19 + TypeScript + Vite, TanStack Query, Tailwind CSS 4, Vitest — see its README |
| [`docs/`](docs) | Requirements, domain rules, architecture, API contract, plan, decision register |
| [`.github/`](.github) | Copilot instructions and prompts |

## Prerequisites

Verified locally with: Ruby 4.0.9, Node 26.13.1 / npm 12.2.2, PostgreSQL 14.25 (Homebrew).
Ruby is pinned in `backend/.ruby-version`; dependency versions are pinned by
`backend/Gemfile.lock` and `frontend/package-lock.json`. PostgreSQL must be running and reachable
over the default local socket (or set `DATABASE_URL`, see `backend/.env.example`).

## Run locally

Start your existing local PostgreSQL service first (`brew services start postgresql@14` on the
reviewed machine). Review any exported `DATABASE_URL` before running setup. On a new local database:

```sh
make setup                       # installs locked dependencies; prepares local databases
```

Use **separate terminals** for the API, frontend and tests. In the backend terminal:

```sh
cd backend
# New local development database only; no RESET flag:
RAILS_ENV=development bin/rails db:seed
read -r -s DEMO_WRITE_KEY         # enter a locally chosen key; do not put it in history
export DEMO_WRITE_KEY
RAILS_ENV=development bin/rails server
```

In the frontend terminal:

```sh
cd frontend
npm run dev
```

Open `http://localhost:5173`; Rails defaults to `http://localhost:3000` (`/up` health check).
The revision form accepts the same locally entered key and keeps it only in React memory; reload
or an invalid-key response discards it. Without a server key writes correctly fail closed with 403.
All employee data is synthetic. Never use RESET on existing development data without approval.

The SPA uses the public `VITE_API_BASE_URL` (development default `http://localhost:3000`). Never put
secrets in `VITE_*`. Rails does not automatically load `.env`; see the safe examples and detailed
[backend](backend/README.md) / [frontend](frontend/README.md) instructions.

## Checks and current evidence

RSpec now refuses unverified database targets, including an inherited development environment.
In a separate test terminal, from `backend/`:

```sh
bundle exec rspec spec/safety/test_database_safety_spec.rb  # no DB connection or writes
ruby script/prepare_test_database.rb                      # NEW local DB only; prints env-file path
# Source the exact local environment file printed above, then:
FULL_SEED=1 bundle exec rspec
bin/rubocop --cache false
bin/rails zeitwerk:check
```

The generated environment must stay in the test terminal. It explicitly identifies and attests the
new disposable DB. Do not point tests at `backend_development`; name matching alone cannot authorize
cleanup. The [backend README](backend/README.md) explains the connection guard and safe commands.

From the root, with the installed Node toolchain:

```sh
VITE_API_BASE_URL=http://localhost:3000 make frontend-check
```

Latest local QA: **358 backend examples**, **55 frontend tests**, typecheck, lint, configured build,
real-browser corrections/revision/stale checks and a 1,000-record history fixture. See
[final local QA](docs/final-local-qa.md), the historical [assessment audit](docs/final-assessment-audit.md)
and the reproducible [browser smoke procedure](docs/local-browser-smoke.md). Current measured read
performance and remaining limits are in those reports; unit counts are not production certification.

`make backend-check`/`make check` invoke setup and a network advisory scan as well as tests; use the
attested test environment first. Production builds require an explicit public API origin. No
hosted CI or deployment is configured. **G1 remains OPEN; hosted DR-20 verification and DR-22 are
unchanged.** Deployment, video and final submission remain separate work.

## AI-assisted development

Development of ACME Salary Management intentionally utilized AI agentic tools (specifically **GitHub Copilot** and **OpenAI Codex**) to accelerate architecture design, Rails backend development, React frontend implementation, and comprehensive test suite authoring under disciplined human engineering oversight.

### 1. Concrete prompt and instruction artifacts

The repository contains the exact directives and prompt instructions used to steer the AI models:

- [`.github/copilot-instructions.md`](.github/copilot-instructions.md): Authoritative repository guardrails enforcing domain rules, source-of-truth document hierarchy, strict avoidance of binary floating-point math (`BigDecimal` and PostgreSQL `numeric` only), immutable salary history, row-lock transaction order, fail-closed write-key authentication, and test database safety.
- [`.github/prompts/architecture-phase.prompt.md`](.github/prompts/architecture-phase.prompt.md): Architectural prompt framing problem constraints, requirements traceability, domain decisions (DR-01 through DR-24), trade-off analysis, and staged acceptance gates before application coding.
- Targeted verification directives: Specific prompts instructing the creation of multi-threaded database concurrency tests (`spec/services/salary_revisions/concurrency_spec.rb`) to verify row-level locking, and attestation token guards (`spec/test_database_safety.rb`) to isolate disposable test environments.

### 2. Implementation scope assisted by AI

- **Backend (Rails 8.1 API):** Scaffolding, database migrations (integrating `btree_gist` temporal exclusion constraints, partial unique indexes, and domain CHECK constraints), domain services (`SalaryRevisions::Create`), query objects (`Employees::Directory`, `Analytics::Summary`, `ReferenceDataQuery`), streaming CSV export (`Employees::CsvExport`), serializers, and the deterministic 10,000-employee synthetic seed generator (`Seeds::DemoDataset`).
- **Frontend (React 19 + TypeScript):** Vite SPA setup, TanStack Query hooks, URL-synchronized filtering, debounced search, responsive layout, accessible form controls, in-memory write-key provider, and dashboard analytics.
- **Testing & Verification:** Comprehensive RSpec unit/service/request test suites and Vitest/Testing Library workflow tests.

### 3. Human engineering decisions and independent review

All AI-suggested designs were critically reviewed against product requirements and software engineering fundamentals:
- **Product scope:** Base salary only; monthly/annual frequencies; deliberate exclusion of payroll execution, live FX, and multi-tenant authentication.
- **Financial accuracy:** Enforcing that calculations happen in PostgreSQL/Rails rather than the client; using exact numeric medians rather than `percentile_cont` (which coerces values to IEEE 754 float); rounding per-employee annual USD values to cents before aggregating.
- **Concurrency & immutability:** Requiring pessimistic row locks (`Employee.lock.find`), single-clock reads, and stale-token checks (`expected_current_salary_record_id`) so historical salary records remain strictly immutable.
- **Decision governance:** Storing formal trade-offs and rationale in [`docs/domain-decisions.md`](docs/domain-decisions.md) and tracking approval status in [`docs/architecture-review.md`](docs/architecture-review.md).

### 4. Verification and validation methodology

No AI output was accepted without deterministic verification:
- **Automated test execution:** Fast, isolated RSpec examples (running against attested disposable databases only) and Vitest tests.
- **Live browser validation:** Chrome DevTools smoke testing covering real-world user flows, keyboard navigation, focus management, and mobile viewport adaptability.
- **Database integrity audits:** Direct read-only SQL queries verifying exact record counts (10,000 employees, 16,055 salary records), interval contiguity, and zero overlapping intervals or exchange rate mismatches.

### 5. Critical AI mistakes identified and corrected

Audits revealed several subtle defects in AI-generated code that were caught and corrected:
1. **Silent database decimal rounding:** PostgreSQL `numeric(14,2)` silently rounds a third decimal place. The AI initially omitted application-level format validation; fixed by adding `SalaryAmount.errors_for` regex checks before database persistence.
2. **Numeric NaN acceptance:** PostgreSQL numeric types accept `'NaN'`, which could corrupt aggregate calculations. Database CHECK constraints were added across amount, rate, and snapshot columns.
3. **Search input focus loss:** In the React directory page, keying the component tree to query parameters caused input unmounting on debounced URL updates. Fixed by preserving the input instance across URL synchronization.
4. **Unicode length mismatch:** JavaScript string `.length` counts UTF-16 code units while Ruby `String#length` counts Unicode codepoints, leading to validation discrepancies on emojis. Fixed by harmonizing codepoint counting and ASCII whitespace trimming.
5. **Test database isolation hazard:** Initial AI test helpers allowed tests to run against `backend_development` if environment variables were misconfigured. Fixed by introducing `TestDatabaseSafety` which verifies a unique cryptographic database comment marker before permitting writes.
6. **CSV timestamp formatting:** Initial CSV serialization used standard ISO 8601 second resolution rather than the API contract's microsecond precision; aligned to `Timestamp.call`.

## Conventions

`.editorconfig` sets whitespace for every language. Ruby style is enforced by RuboCop
(rubocop-rails-omakase) and TypeScript style by ESLint. No code formatter such as Prettier is
installed, because it is not in the approved baseline (DR-24).
