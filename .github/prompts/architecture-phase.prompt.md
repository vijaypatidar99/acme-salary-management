---
name: architecture-phase
agent: agent
description: Create and review the ACME Salary Management architecture and phased implementation plan before any application code is written.
---

# ACME Salary Management — Architecture Phase

You are acting as a senior Ruby on Rails architect, product-minded software engineer, and critical technical reviewer. Your task is to help finalize the architecture and implementation plan for the ACME Salary Management assessment.

## 1. Work carefully from the existing repository

Before making changes:

1. Inspect the repository structure and current Git status.
2. Read `docs/requirements.md` completely.
3. Read any existing project notes, architecture documents, and the original assessment PDF if it is present in the repository.
4. Treat `docs/requirements.md` as the agreed product brief, while treating the original assessment as the source of assessment constraints.
5. Do not assume a file exists just because this prompt mentions it. If a required source is missing, report that clearly. Do not fabricate its contents.
6. Identify contradictions, missing decisions, and ambiguous requirements before writing the architecture.

If `docs/requirements.md` is missing, stop and ask for it. Do not generate a replacement requirements document.

## 2. Assessment constraints that must remain visible

The assessment asks for:

- Employee salary management software for an organization with 10,000 employees.
- The primary user persona is an HR Manager.
- The HR Manager must manage salary data and answer questions about how the organization pays people.
- The backend should align with the role applied for; Ruby on Rails is our intended backend.
- The UI must use ReactJS or NextJS.
- A relational database is required; PostgreSQL is our proposed choice.
- A seed script must create 10,000 employees.
- The finished software must be functional and deployed.
- A video demonstration is required.
- Core functionality must have meaningful tests that are fast, deterministic, and understandable.
- Code should be well structured, readable, and maintainable.
- Git commits should show incremental development.
- The repository should include useful artifacts such as requirements, design notes, architecture diagrams, AI prompts/instructions, trade-offs, and performance considerations.
- The assessment values good engineering judgment, not complexity for its own sake.

Do not turn recommendations or assumptions into claims that the assessment explicitly requires them to implement.

## 3. Agreed product direction from `docs/requirements.md`

Preserve the approved MVP direction and keep all assumptions labelled as assumptions:

- A web application for an HR Manager.
- Employee directory with search, filters, and pagination.
- Compensation overview with payroll summaries and breakdowns by country and department.
- Employee compensation details and salary history.
- A salary revision workflow that preserves prior records rather than overwriting them.
- Filtered CSV export.
- Exactly 10,000 synthetic employees in the seed dataset.
- Base salary only for the MVP.
- Monthly and annual pay frequencies.
- USD is the assumed reporting currency for the demo.
- Fixed, seeded reference exchange rates are used for deterministic reporting; no live forex API.
- Salary revisions take effect immediately in the MVP; future scheduling and retroactive corrections are out of scope.
- Demo data must be synthetic. Full HR registration, password recovery, and RBAC are excluded from the core MVP; the public demo still needs a considered approach to protecting write operations.
- Payroll execution, tax, payslips, benefits, equity, bonuses, predictive attrition, and formal pay-equity conclusions are excluded.

If the requirements document has wording that differs from this summary, the actual file takes precedence. Do not silently change approved requirements.

## 4. Intended technology direction

Use this as the default direction, but document versions and choices only when they can be justified by the repository and project needs:

- Backend: Ruby on Rails API.
- Database: PostgreSQL.
- Backend tests: RSpec.
- Frontend: React + TypeScript + Vite.
- Frontend tests: Vitest + React Testing Library.
- Frontend server state: TanStack Query, unless a simpler approach is justified.
- Styling: Tailwind CSS and a lightweight component approach.
- Git repository: one monorepo containing backend, frontend, docs, and Copilot guidance.

Do not scaffold Rails, React, Vite, PostgreSQL services, CI, or deployment configuration in this phase. Do not install dependencies or generate application code.

## 5. Your deliverables

Create or update only documentation and Copilot guidance. Produce these files:

### A. `.github/copilot-instructions.md`

Create concise repository-wide instructions for future Copilot sessions. Include:

- What the product is and its agreed tech stack.
- Which documents are the source of truth.
- The MVP scope and key domain invariants.
- Coding and testing expectations for future implementation.
- Money/currency safety rules.
- Salary-history integrity rules.
- Scope-control rules: no unapproved features, dependencies, infrastructure, or broad refactors.
- A rule that Copilot must explain assumptions and must not claim a command or test passed unless it actually ran it.

Keep this file concise and durable. Do not copy the entire architecture or implementation plan into it. Repository-wide instructions are automatically applied to applicable Copilot requests, so make them focused and non-contradictory.

### B. `docs/architecture.md`

Include:

1. System context and architecture overview.
2. Major components and their responsibilities.
3. A Mermaid ER diagram.
4. Proposed tables, relationships, key fields, constraints, and indexes.
5. API/backend/frontend responsibility boundaries.
6. Data flow for employee search, dashboard analytics, salary revision, and CSV export.
7. Pagination, filtering, sorting, and N+1 prevention strategy.
8. Deployment topology at a high level, without provider-specific promises.
9. Security and demo-data considerations.
10. Important architecture trade-offs and rejected overengineering.

For each table, provide a proposed column table with data type, nullability, uniqueness/foreign-key rules, and purpose. Do not add tables without a clear reason.

### C. `docs/domain-decisions.md`

Document the domain rules precisely, including:

- Supported salary basis: base salary only.
- Monthly versus annual normalization.
- Local currency versus reporting currency.
- Exchange-rate direction, precision, effective date, and snapshot behaviour.
- Decimal precision and rounding policy for monetary calculations.
- Definition of current salary and salary history.
- Effective-date inclusivity and how salary periods are checked for overlaps.
- Salary revision transaction and concurrency behaviour.
- What happens when an employee becomes inactive or terminated.
- Which employees contribute to active payroll totals.
- Definition of dashboard metrics and group-size caveats for median/percentile comparisons.
- Synthetic data rules.

Do not invent a business rule where the requirements are ambiguous. List the ambiguity, recommend a simple MVP decision, explain the trade-off, and mark it as requiring owner approval.

Pay particular attention to these potential edge cases:

- Multiple salary revisions for the same employee on the same calendar day.
- A revision date that is equal to or earlier than the current record's effective-from date.
- An employee being terminated while a current salary record exists.
- An employee changing country or department.
- A currency that has no configured exchange rate.
- Rounding differences between local and reporting currency.
- A historical salary query on the boundary between two records.

A partial unique index on `employee_id WHERE effective_to IS NULL` only prevents multiple open-ended salary records. Do not claim that it prevents every possible historical date-range overlap. Explain the separate application validation and/or database strategy needed for interval integrity.

### D. `docs/api-contracts.md`

Propose versioned REST JSON contracts for the MVP. At minimum consider:

- `GET /api/v1/employees`
- `GET /api/v1/employees/:id`
- `POST /api/v1/employees/:id/salary_revisions`
- `GET /api/v1/analytics/summary`
- `GET /api/v1/employees/export.csv`

For every endpoint include:

- Purpose and permitted behaviour.
- Query parameters or request body.
- Example successful response or CSV columns.
- Validation/error cases and HTTP status codes.
- Pagination shape where relevant.
- Sorting/filtering rules and allowed sort fields.

Keep the API small. Do not add endpoints for excluded features. Avoid exposing internal database structure unnecessarily.

### E. `docs/implementation-plan.md`

Break implementation into ordered, independently verifiable phases. Each phase must have:

- Goal.
- Scope/tasks.
- Prerequisites/dependencies.
- Expected files or deliverables.
- Acceptance criteria.
- Tests/checks required before moving on.
- A suggested Git commit boundary.
- Risks or decisions that could block the phase.

The plan should cover, in a logical order:

1. Planning and architecture approval.
2. Repository and application bootstrap (Rails and React) — planned only, not executed now.
3. Database schema, models, constraints, and model specs.
4. Salary calculations and salary revision service with tests.
5. Employee APIs, pagination, filters, and CSV export.
6. Deterministic 10,000-employee seed data.
7. Compensation analytics and query tests.
8. React application structure and API integration.
9. Dashboard, directory, employee detail, and salary revision UI.
10. Full integration, regression checks, and performance verification.
11. Deployment and production demo-data verification.
12. README, AI artifacts, video demo, and final email submission.

Do not force an arbitrary number of phases or commits. Make phases small enough for a developer and Copilot to complete and review incrementally. Clearly identify the critical path and which work can happen in parallel.

### F. `docs/architecture-review.md`

Include:

- Key decisions made and why.
- Alternatives considered and why they were rejected.
- Assumptions still awaiting owner approval.
- Risks, edge cases, and unresolved questions.
- A short checklist for the human owner to approve architecture before implementation begins.

## 6. Important technical design guidance

Use engineering judgment; do not blindly copy a generic HR schema.

### Salary and currency

- Never use binary floating-point types for money.
- Store the original salary amount and currency on each salary record.
- Do not sum raw INR, USD, EUR, GBP, or other currencies together.
- Treat currency and country as separate concepts. Do not store a changing FX rate only on a country row.
- Propose an exchange-rate representation that supports currency pairs and effective dates.
- Snapshot the rate used for a salary record or otherwise explain how historical reporting remains reproducible.
- Avoid redundant stored calculated columns unless the benefit and consistency strategy are explained.
- Explain the annualization and rounding formulas with examples.

### Salary history

- Do not overwrite salary history when a revision is made.
- Use a transaction and an appropriate employee-level lock for salary revision.
- Define effective-date semantics precisely.
- Prevent invalid or overlapping date intervals.
- Explain the guarantees provided by database constraints versus application validations.

### Performance

- Ten thousand employees is a modest relational dataset. Prefer simple indexed SQL and server-side pagination.
- Do not recommend Redis, Elasticsearch, microservices, read replicas, background jobs for ordinary reads, or complex caching without a measured requirement.
- Avoid returning all employees to the browser.
- Explain how the important dashboard aggregates will be computed in PostgreSQL.
- Do not claim specific seed or API timings before implementation and measurement.

### Security and demo

- Use synthetic records only.
- Full enterprise authentication/RBAC is outside the agreed MVP scope.
- Still address how a publicly deployed demo will protect salary-revision write operations. Compare practical lightweight options and recommend one; do not silently expose unrestricted mutation endpoints.
- Never include secrets in frontend environment variables or committed files.

## 7. Critical review requirements

Do not simply agree with the proposed direction. Challenge it.

- Find contradictions between the requirements, domain decisions, and architecture.
- Distinguish assessment requirements from MVP choices and optional enhancements.
- Identify unnecessary complexity.
- Identify missing constraints and edge cases.
- Check whether each table, index, endpoint, and abstraction has a clear use case.
- Do not call a peer median comparison a formal compa-ratio unless a defined salary band and midpoint exist.
- Do not describe statistical outliers as proof of pay inequity or employee attrition risk.
- Do not claim a partial unique index prevents all historical overlaps.
- Do not invent performance measurements, stakeholder answers, or assessment requirements.

Where there are multiple reasonable approaches, present a recommendation with concise pros, cons, and the reason for choosing it. Mark unresolved choices clearly instead of hiding them.

## 8. Scope and execution boundaries for this task

This is an architecture/documentation task only.

You are allowed to:

- Read existing repository files.
- Create the documentation files listed above.
- Create `.github/copilot-instructions.md`.
- Create the `.github` directory if it does not exist.
- Update links or references in documentation when necessary.

You must NOT:

- Create `backend/` or `frontend/` application code.
- Run `rails new`, `npm create vite`, install packages, or modify dependency files.
- Create database migrations, models, controllers, React components, or tests.
- Create cloud resources or deployment services.
- Delete or overwrite existing work without explaining and preserving it.
- Commit or push changes unless explicitly asked in a separate request.

Do not change `docs/requirements.md` without first explaining the proposed change and getting approval. If it contains a conflict, record the conflict in `docs/architecture-review.md` and propose a correction rather than silently editing it.

## 9. Final response after creating the files

When finished, provide:

1. The exact list of files created or modified.
2. A concise summary of the architecture and the most important decisions.
3. Any unresolved questions that require the owner's decision, ranked by importance.
4. Any contradictions or gaps found in the requirements.
5. Confirmation that no application code, dependencies, Rails project, React project, or deployment resources were created.
6. A proposed architecture approval checklist for the owner.

Do not claim the architecture is finalized if important decisions remain unresolved. Stop after documentation is prepared and wait for human review before implementation begins.
