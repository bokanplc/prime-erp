# BOKAN ERP V6.7 — Application Persistence Matrix (updated 2026-11-07)

## Scope authority

The owner-directed scope reset in `docs/V67_APPLICATION_MIGRATION_SCOPE_2026-11-07.md` is authoritative. The target remains the complete V6.7 application (91 tab panels in the reviewed source), with standard non-stock functionality migrated. The owner will provide fresh reconciled business data later.

Do not treat historical stock, sales, purchase, customer, or financial reconciliation as a prerequisite for application migration. Preserve existing live records; do not import, reconcile, certify, or delete them as part of this phase.

## Verified production persistence adapters and workflows

| Application area | Current persisted path | Current state | Remaining application work |
|---|---|---|---|
| Authentication / company context | Supabase Auth + active `company_memberships` | Source adapter present; company/role context is derived from active membership | Complete browser sign-in, company switching, and real role-by-role access tests |
| CRM customers | `customers`, `crm_customer_assignments` | Canonical CRM bridge supports company-scoped customer reads/create/update and guarded reassignment | Verify full legacy customer screens and all role workflows in browser |
| CRM activity history | `crm_activities` | Bridge supports company-scoped activity creation and history, including calls, visits and follow-up dates | Verify reminder behavior, escalation, salesperson attribution and history screens |
| CRM pipeline | `crm_opportunities` | Sales Pipeline screen now loads and creates opportunities through the canonical CRM adapter | Verify edit/stage progression and sales-manager assignment workflow |
| After-sales follow-up | `crm_after_sales_tasks` | Bridge supports task list/create/update | Verify reminders and task ownership in authenticated browser |
| Sales Orders | `sales_documents`, `sales_document_items`, guarded draft RPC | V6.7 Sales Orders screen loads and creates company-scoped drafts through the RPC | Verify browser workflow and approval UI; stock issue and payment actions remain parked |
| Sales targets | `sales_targets` | Reads, writes, updates and deletes explicitly scope to active company; administration controls are manager-only in UI and RLS | Verify commission calculations with newly supplied data and authenticated roles |
| Trip plans | `trip_plans` | Create/update/delete/list paths now include active company context | Verify late-cutoff exception and notifications in browser |
| Visit reports | `visit_reports` | Create/update/delete/list paths now include active company context | Verify due-date rules and employee/manager visibility in browser |
| Notifications | `notifications` | Insert and list now include active company context | Verify recipient visibility, read state and notification delivery |
| Expenses | `expenses` | Entry, update, ledger reads and deletion now explicitly scope to active company | Verify finance-role editing and employee expense-entry workflow |
| Transaction costs | `transaction_costs` | Company-scoped adapter supports cost list/create | Keep non-stock direct/operating costs distinct; inventory landed-cost allocation is parked |
| Proforma | `proformas`, company settings and guarded RPCs | Existing company-scoped production adapter and save workflow | Verify final PDF/document output and authenticated company settings |
| Supply / logistics planning | `supply_shipments`, `delivery_orders` | Company-scoped bridge for shipment and delivery planning | Verify planning-only UI; do not implement purchase receiving or sales stock issue in this phase |
| Finance | Ledger and fiscal-period reads; journal RPC | Production adapter present | Verify accounting screens without enabling receipts/payments or stock-derived costing |
| Document repository | Private Storage + company-scoped `documents` | Existing private document upload/list/delete path | Verify upload/download permissions and staff/admin behavior |
| Policy handbook | `company_policy_documents` | Company-scoped employee read and admin print controls | Verify server-side access and print restrictions |
| Profitability | Posted invoices, stock movement costs and transaction costs | Source adapter exists but depends on stock costing | Parked until owner supplies fresh data and reopens inventory costing |

## Explicitly parked by owner direction

Do not work on or enable the following as release blockers in this application phase:

- Historical stock balances and stock-swap reconciliation.
- Sales stock posting / stock issue.
- Purchase receiving / stock receipt.
- Inventory costing, valuation, COGS and landed-cost allocation.
- Import or reconciliation of old customer, sales, purchase, stock or financial records.

Existing live rows—including the previously seeded 61-piece Yellow Plywood opening-stock row and prior draft documents—remain untouched. They are not the owner's new dataset and must not be used as current operational truth.

## Deferred HR

HR remains outside the initial production allowlist. Preserve source and schema for later, but do not enable HR modules in the first release.

## Remaining full-application work

The 91-tab V6.7 interface is preserved. A visible screen is not considered migrated merely because its markup exists. Remaining work is to inventory every screen's actions and replace localStorage/demo-only behavior with the appropriate company-scoped application service, or clearly disable a function that is outside the current scope.

Priority order:

1. Finish authenticated browser verification for the CRM, Sales Pipeline, Sales Orders draft, Sales Targets, Expenses, Trip Plans, Visit Reports and Notifications paths.
2. Complete company/user administration, role changes and active-company switching through safe membership workflows.
3. Complete document repository, proforma, policy handbook and non-stock finance/expense screens.
4. Audit the remaining V6.7 tabs for localStorage/demo-only state; migrate their standard non-stock behavior or keep them disabled until verified.
5. Re-run the complete release builder and all source, schema, role, and browser checks.

## Release guard

Production remains fail-closed. Do not enable production tabs or issue a staff release link until all in-scope non-stock application workflows have passed authenticated role, RLS, persistence, error-handling and browser checks. Do not reduce the application to a sample or extracted mini-app.
