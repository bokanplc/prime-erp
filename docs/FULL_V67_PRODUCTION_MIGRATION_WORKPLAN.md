# BOKAN ERP V6.7 — Full application migration workplan

**Status:** active integration work on `feature/inventory-costing-and-receiving-audit`; staging/preview only. This is not a production-readiness claim.

## Controlling owner direction (2026-11-07)

Migrate the complete 91-panel V6.7 application and its standard non-stock functionality. The owner will supply fresh, reconciled business data in a later phase. Do not import, reconcile, certify, or use historical stock, sales, purchase, customer, or financial records as acceptance criteria. Preserve all existing live rows as-is.

The initial release scope excludes HR. Park historical stock balances/swaps, sales stock issue/posting, purchase receiving/stock receipt, inventory costing/valuation/COGS, and landed-cost allocation. Do not expose these actions in the first release. Customer receipts, supplier payments and formal settlement remain in Peachtree, the accounting system of record.

This scope supersedes earlier workplan text that made historical reconciliation, HR, stock posting, purchasing receipt, or Prime company records prerequisites. Do not change `main`, merge, promote production, alter production allowlists, or distribute an employee link until the release gates pass and the owner explicitly requests that release action.

## Migration status at this checkpoint

The full reviewed V6.7 HTML source (91 tab panels) is preserved. A visible panel is not counted as migrated unless its standard in-scope behavior is connected to the canonical company-scoped service or intentionally disabled.

### Integrated application paths — source-level implementation present

- Authentication/company context adapter based on Supabase Auth and active `company_memberships`.
- CRM customer, activity history, opportunity/pipeline and after-sales task adapters.
- Sales Orders company-scoped draft creation; approval UI and all stock/payment actions remain gated.
- Sales Targets company-scoped reads/writes/deletes with manager-only administration.
- Expenses and transaction-cost list/create paths with active-company scope.
- Trip Plans, Visit Reports and Notifications company-scoped persistence paths.
- Proforma company settings and guarded save workflow.
- Supply/logistics planning bridge for shipment and delivery planning only.
- Finance read/reporting adapters that do not record receipts/payments or depend on stock costing.
- Private company document repository and policy handbook paths.

These are implementation checkpoints, not blanket production approvals. The current persistence matrix records the module-by-module evidence and outstanding checks in `docs/V67_PRODUCTION_PERSISTENCE_MATRIX_2026-11-06.md`.

### Remaining work before a staff release

1. Complete real authenticated browser tests for sign-in/sign-out/session refresh, active-company selection, role-specific navigation, save/edit/reload, and denied access.
2. Complete trusted company/user administration and employee invitation/membership lifecycle; verify manager, salesperson and data-entry permissions without creating unrequested accounts.
3. Finish browser acceptance for CRM ownership, calls/visits/reminders/history, opportunity stage progression, Sales Orders draft workflow, targets, expenses, trip plans, visit reports and notifications.
4. Verify Proforma PDF/document output and company settings; verify private document upload, signed download, retention and admin/employee boundaries; verify policy handbook read and admin-only print.
5. Complete in-scope non-stock finance and management reporting screens as safe read-only or operational workflows; no receipt/payment or stock-derived costing workflows.
6. Audit every remaining V6.7 panel for localStorage/demo-only state. Migrate standard in-scope behavior to company-scoped persistence or keep the unsupported action disabled. Do not shrink or replace the full interface.
7. Run source guards, schema/RLS tests, role/isolation tests, sanitized release build, and a current-commit Vercel preview. Fix failures and repeat.
8. Only after all gates pass, review a non-empty source-reviewed production tab allowlist and separately confirm production promotion/release authorization.

## Release acceptance

A module is eligible for production only when its screen and payload contract map to the canonical schema; company and role boundaries are enforced server-side; writes are trusted and transactional where needed; anonymous, wrong-role, inactive-membership, cross-company, invalid-input, duplicate and rollback cases are tested; authenticated browser create/edit/reload behavior passes; and production cannot silently fall back to localStorage or demo data.

## Parked / deferred (not blockers for this application phase)

- HR and payroll.
- Historical business-data import or reconciliation.
- Stock balances/swaps, stock issue/posting, purchase receiving, inventory costing/valuation/COGS and landed-cost allocation.
- Customer receipts, supplier payments and accounting settlement in ERP.

No live business data is to be deleted or rewritten as part of this migration phase. Fresh data onboarding is a separate future phase after the owner supplies the reconciled dataset.
