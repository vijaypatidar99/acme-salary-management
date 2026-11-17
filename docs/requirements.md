# ACME Salary Management — One-Page Requirements

**Status:** Pre-implementation draft · **Version:** 1.0 · **Date:** 17 November 2026

## Goal
Replace ACME’s spreadsheet-based salary tracking with a web application that lets an HR Manager find employee compensation records, maintain salary changes without losing history, and understand how base salaries are distributed across the organization.

## Primary user and problem
**Primary user:** ACME HR Manager.

ACME manages salary information for 10,000 employees across multiple countries in spreadsheets. This makes it difficult to locate reliable records, preserve salary-change history, and answer organization-wide questions—especially when salaries use different currencies and pay frequencies.

## MVP scope and core workflows

1. **Find employees:** View a paginated employee directory; search by employee name or ID; filter by country, department and employment status. Open an employee profile to see relevant employee details and compensation.
2. **Understand compensation:** View active headcount and annualized base-pay totals by country and department, with organization-level totals in a common reporting currency. Show local-currency amounts where relevant. Provide average and median comparisons for selected groups, with group size visible so small samples are not misleading.
3. **Record a salary revision:** Enter a new base-salary amount, currency, pay frequency (monthly or annual), and reason. A revision takes effect immediately in the MVP. Preserve the previous salary record, its effective dates and reason; do not overwrite history. Reject invalid or non-positive amounts and prevent overlapping salary periods.
4. **Export data:** Export the employee/salary rows matching the current directory filters to CSV.
5. **Demonstrate scale:** Provide a repeatable seed script that creates exactly 10,000 synthetic employees across multiple countries, currencies, departments, job levels and employment statuses, with current and sample historical salary records.

## Deliberate exclusions
The MVP will not provide payroll execution, tax or statutory deductions, payslips, bonuses, equity, benefits, allowances, hourly or variable compensation, bulk spreadsheet import, live foreign-exchange feeds, future-dated salary scheduling, retroactive corrections, predictive attrition, formal pay-equity conclusions, or full HR employee-lifecycle management. Full user registration, password recovery, role-based access management and corporate SSO are also excluded; the deployed assessment demo will use synthetic data and appropriate demo-only access protection. These exclusions keep the work focused on accurate base-salary management and useful compensation reporting.

## Key assumptions to validate
- **Reporting currency:** Use USD as the MVP reporting currency for cross-country rollups. Retain each salary’s local currency and the conversion rate used. Use fixed, seeded reference rates for deterministic demo results; these are illustrative planning rates, not live financial rates.
- **Pay basis:** Track base salary only, with monthly and annual frequencies. Annualize monthly amounts by multiplying by 12; annual amounts remain unchanged.
- **Payroll totals:** Organization-wide and group totals include active employees and use annualized, converted base salary. Do not add raw amounts from different currencies.
- **Revision timing:** New revisions take effect immediately. Historical records are retained; scheduled future changes and retroactive corrections are deferred.
- **Data:** All demo employee and salary information is synthetic. No real employee data will be used.

## Success criteria
The deployed application lets an HR Manager search and filter the 10,000 seeded employees, inspect current and historical salary records, make a valid salary revision without losing history, view correctly currency-normalized compensation summaries, and export the filtered results. Core business rules are covered by fast, deterministic tests. The repository includes this requirements document, relevant design/trade-off and AI-use artifacts, incremental commits, a working deployment and a short video demonstration.
