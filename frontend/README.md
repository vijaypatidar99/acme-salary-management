# ACME Salary Management — frontend

React 19, TypeScript (strict), Vite, React Router, TanStack Query, Tailwind CSS 4, Vitest and
React Testing Library. Product rules and the API contract are in [`../docs`](../docs).

## Scripts

| Command | What it does |
|---------|--------------|
| `npm run dev` | Dev server on http://localhost:5173 |
| `npm run typecheck` | `tsc -b` (strict mode) |
| `npm run lint` | ESLint |
| `npm test` | Vitest, once (`npm run test:watch` to watch) |
| `npm run build` | Typecheck, then production build into `dist/` |

## Configuration

`VITE_API_BASE_URL` is the API origin (see `.env.example`). It is optional in development and
required for production builds. Every `VITE_*` value is public in the bundle, so it must never
hold a secret. The write passphrase (DR-02, decided under delegation; owner gate review pending) will live in in-memory React state only.

## Layout (`src/`)

Tests sit next to the code they cover as `*.test.ts(x)`. Empty directories hold a `.gitkeep`.

| Path | For |
|------|-----|
| `main.tsx` | Entry point |
| `app/` | App root: providers (`App.tsx`) and routes (`router.tsx`) |
| `components/layout/` | Page shells shared by routes (`AppLayout`) |
| `components/ui/` | Generic primitives (buttons, inputs, tables) |
| `components/common/` | Shared pieces with some app knowledge (e.g. `NotFoundPage`) |
| `features/<name>/` | One folder per workflow: its page, components, hooks and API calls. `dashboard/`, `employees/`, `compensation/`, `salary-revisions/` are empty until their phases; `health/` is the temporary API-status page |
| `lib/` | `api.ts` (base URL, and later the API client) and `query-client.ts` |
| `types/` | API and environment types |
| `test/` | Test setup and helpers |

Add `hooks/`, `utils/` or `constants/` only when something is genuinely shared across features
(e.g. the display-only money formatter); until then keep code inside its feature.

Money values are decimal strings from the API; the frontend formats them for display only and
never adds, compares or converts them.
