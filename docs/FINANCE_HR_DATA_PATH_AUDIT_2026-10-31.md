# BOKAN ERP V6.7 — Finance & HR Data-Path Audit
**Date:** 2026-10-31
**Branch:** `deploy/secure-staging`
**Status:** source mapping only; no Finance or HR production tabs enabled.

## Finance — existing V6.7 UI and local data paths

The full application contains General Ledger, Chart of Accounts, AR, AP, Bank & Cash, VAT/tax, procurement, inventory control, fixed assets, budget control, payroll, audit, posting register, period close, close controls, exceptions and reporting screens.

The principal browser-local stores found in the actual V6.7 source are:
- `prime_v22_corporate`: arrays for `gl`, `ar`, `ap`, `bc`, `po`, `ic`, `fa`, `budget`, `payroll` and `audit`.
- `prime_v40_transactions`: a separate simulated transaction/posting list for AR invoices and collections, AP bills and payments, inventory receipts/issues, and derived trial-balance/subledger summaries.
- `prime_v41_approvals` and `prime_v41_audit`: local approval queue and audit log.
- `prime_v34_close_control`: local close-control areas and statement-readiness flags.
- `prime_v35_postings`: local posting register.
- `prime_v51_exceptions`: local exception workbench.
- `prime_v52_period_control` and `prime_v52_period_events`: local period status/lock and event history.
- `prime_v53_quality_issues` and `prime_v53_lastscan`: local data-quality scan results.
- `prime_v27_ops`, `prime_v28_control`, `prime_v29_control`, `prime_v30_controls`, `prime_v33_reconciliation`: additional operations/master/control state consumed by the finance and close workflows.

### Existing Finance production bridge — not live-ready

The source has a `BOKAN_FINANCE_PRODUCTION` bridge, but it is not a working live contract. It calls these nonexistent tables/RPCs:
- `bokan_journal_entries`
- `bokan_ar_invoices`, `bokan_ar_receipts`
- `bokan_ap_bills`, `bokan_ap_payments`
- `bokan_fiscal_periods`
- `bokan_finance_close_readiness`

The bridge scopes queries with a company-code string and `window.sb`, rather than deriving the UUID from the authenticated active company membership profile and using the shared authenticated Supabase client. Its create methods accept raw payloads without a complete approved-source, balanced-journal, idempotency, period-lock and reversal contract. It must remain disabled.

### Finance schema direction

Do not create duplicate AR/AP source documents beside the existing `sales_documents`, `purchase_documents`, `sales_payments` and `supplier_payments`. Treat those approved source documents and the existing `stock_movements` / `proformas` as source records. The accounting layer should add a company-scoped chart of accounts, fiscal periods, journal headers and journal lines, plus trusted posting/reversal operations. Posting must:
1. Verify the source document belongs to the active company and is approved.
2. Create balanced debit/credit lines atomically.
3. Reject duplicate source postings using a unique source/idempotency key.
4. Reject posting into a closed period.
5. Preserve immutable posted entries; corrections use reversal entries.
6. Reconcile AR/AP and cash/bank balances to the source subledgers.

Bank reconciliation, VAT/WHT controls, budgets, fixed assets and statements should be mapped to these canonical records rather than treated as independent local ledgers.

## HR & Payroll — existing V6.7 UI and local data paths

The full application contains employee master, attendance, leave, performance, disciplinary, HR reports, payroll preparation, payroll register and payroll control screens.

Observed local stores include:
- `prime_v24_attendance`: attendance marks and notes.
- `prime_v25_v26`: arrays for opportunities, orders, receivables, leave, payroll and performance; this is a mixed Sales/HR store.
- `prime_v22_corporate.payroll`: a second payroll array in the corporate finance store.
- `prime_v27_ops` and `prime_v29_control`: master-data and management-control state used by adjacent HR/operations views.

### Existing HR production bridge — not live-ready

The source has a `BOKAN_HR_PRODUCTION` bridge, but all of its core table names are absent from the live Supabase schema:
- `bokan_employees`
- `bokan_attendance_records`
- `bokan_leave_requests`
- `bokan_payroll_runs`, `bokan_payroll_lines`, `bokan_payroll_approvals`
- `bokan_performance_reviews`

It also uses a company-code string and `window.sb` rather than the authenticated active company UUID and shared authenticated client. The live database has no HR employee/attendance/leave/payroll tables yet. The bridge must remain disabled.

### HR schema direction

Build one company-scoped employee master and keep highly sensitive compensation/payroll details in a separately permissioned data set. Add attendance, leave requests and approvals, performance reviews, disciplinary records, payroll runs, payroll lines and payroll approvals only with explicit role separation. Employee self-service must be limited to the employee's own permitted records; managers must see only their company/team scope; HR and payroll access must be separately granted. Payroll calculations, approval transitions and finalization must be server-validated and audited. Do not trust payroll amounts, approvals or period status supplied by localStorage.

## Activation decision

Finance and HR production bridges are **not approved**. Keep the production allowlist empty. First finish the Supply & Logistics browser-authenticated test; then reconcile the CRM UI bridge to the live `crm_*` contracts. Finance schema design should follow the source-document accounting direction above; HR follows with its stricter sensitive-data/RLS model. The full V6.7 screens remain available in demo review mode only.


## General Ledger foundation applied — 2026-10-31

Live Supabase migration: `20261031113713_add_company_scoped_general_ledger_foundation`.

Four company-scoped tables are now present:
- `ledger_accounts` — account code/name, account type, normal balance, parent hierarchy and active/system flags.
- `fiscal_periods` — named date ranges with open/closed/locked states.
- `journal_entries` — draft/posted journal headers, currency, source identity, totals and posting audit fields.
- `journal_lines` — company-matched account and journal references, line numbers, debit/credit amounts.

Security and posting controls:
- RLS is enabled on all four tables. Reads are restricted to active company members; finance writes are restricted to active owner/admin/manager/accountant memberships.
- Composite company foreign keys prevent a journal line from referencing an account or journal belonging to another company.
- Draft lines must have exactly one positive side (debit or credit); account and period codes are constrained.
- Posting validates an open fiscal period, at least two lines, equal positive debit/credit totals, active accounts, and authorized posting identity. Posted headers and lines are immutable through ordinary authenticated access. No business journal was created by the migration.
- No chart-of-accounts seed data, fiscal period, or journal entries were added to either company; finance configuration still requires review before operational use.

Verification performed in rollback-only transactions using the existing authorized admin membership:
- A balanced two-line journal posted successfully and recorded equal totals plus poster/timestamp.
- A draft-line deletion refreshed the draft header totals to zero.
- Test rows were rolled back; live business data remains unchanged.

This is a ledger foundation, not the complete Finance module. Automated posting from approved sales/purchase documents, idempotent source posting, reversal workflow, bank reconciliation, VAT/WHT, budgets, fixed assets, period close, and authenticated browser tests remain outstanding. Keep Finance disabled in the production allowlist.
