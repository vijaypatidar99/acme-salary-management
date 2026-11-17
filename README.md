# ACME Salary Management

Web app for an ACME HR Manager to find employee compensation records, revise base salaries
without losing history, and see how base pay is distributed across 10,000 synthetic employees.

**Status: backend and frontend MVP implemented and locally verified.** The React app now includes
compensation analytics, employee search/filter/pagination, profiles and salary history, protected
salary revisions and CSV export, connected to the Rails API. The frontend check passes 44 tests;
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

```sh
make setup                       # install both apps' dependencies, create the databases
cd backend && bin/rails server   # API on http://localhost:3000 (health check: /up)
cd frontend && npm run dev       # SPA on http://localhost:5173
```

The SPA finds the API through `VITE_API_BASE_URL` (default `http://localhost:3000` in
development) and the API allows the Vite origin through CORS. Both are optional locally; see
`backend/.env.example` and `frontend/.env.example`. Never put secrets in `VITE_*` variables: they
are public in the built bundle.

## Checks

```sh
make check            # everything below
make backend-check    # bin/ci: RuboCop, bundler-audit (network), Brakeman, RSpec
VITE_API_BASE_URL=http://localhost:3000 make frontend-check  # typecheck, lint, tests, configured build
```

No hosted CI, Docker or deployment configuration exists; those belong to Phase 11 and need
owner approval (DR-22).

## Conventions

`.editorconfig` sets whitespace for every language. Ruby style is enforced by RuboCop
(rubocop-rails-omakase) and TypeScript style by ESLint. No code formatter such as Prettier is
installed, because it is not in the approved baseline (DR-24).
