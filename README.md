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

Codex helped inspect and implement the Rails/React MVP, generate regression tests and review domain,
security and integration behavior. The owner chose the product scope and recorded architectural
approvals; delegated decisions and gate acceptance remain tracked in the decision register. Audits
found numeric-NaN and request-handling defects earlier, followed by test-target safety, search-focus,
Unicode validation and CSV precision issues. Corrections were checked using RSpec/Vitest, real local
PostgreSQL and Chrome, with write workflows confined to disposable data. Prompts and guardrails are
in [`.github/`](.github); findings, corrections and measured limits are in the linked reports.
Human owner review is still required; these artifacts do not imply approval or hosted verification.

## Conventions

`.editorconfig` sets whitespace for every language. Ruby style is enforced by RuboCop
(rubocop-rails-omakase) and TypeScript style by ESLint. No code formatter such as Prettier is
installed, because it is not in the approved baseline (DR-24).
