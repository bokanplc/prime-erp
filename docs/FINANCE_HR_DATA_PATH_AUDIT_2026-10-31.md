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

### Existing Finance production bridge — partially reconciled, still disabled

The V6.7 `BOKAN_FINANCE_PRODUCTION` adapter has been corrected against the current live schema:

- General Ledger reads use `journal_entries`; periods use `fiscal_periods`; account lists use `ledger_accounts`.
- Sales and supplier document counts use the canonical `sales_documents` and `purchase_documents` tables. No parallel `bokan_ar_invoices` / `bokan_ap_bills` tables are assumed.
- The adapter resolves the active company code to the live `companies.id` UUID before filtering by `company_id`.
- Journal posting calls the existing atomic `post_journal_entry` RPC. The RPC validates active company membership and finance role, balanced debit/credit lines, active same-company accounts, and an open fiscal period.
- The adapter no longer exposes customer receipt or supplier payment write methods. Those remain in Peachtree, per the project decision.
- The previous nonexistent `bokan_finance_close_readiness` RPC is not called.

Remaining gaps: the adapter still uses the legacy `window.sb` bridge rather than a single shared typed auth context; it does not yet auto-post approved sales/purchase source documents; source-document approval state and idempotency must be enforced before automation; bank/cash, reconciliation, VAT, budgets, fixed assets, period close, statements, and browser authorization tests remain incomplete. Finance must stay disabled.

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

### Existing HR production bridge — schema-backed, still disabled

The live Supabase schema now includes the HR/Payroll tables:
- `bokan_employees`
- `bokan_attendance_records`
- `bokan_leave_requests`
- `bokan_payroll_runs`, `bokan_payroll_lines`, `bokan_payroll_approvals`
- `bokan_performance_reviews`
- `bokan_disciplinary_actions`

The V6.7 `BOKAN_HR_PRODUCTION` adapter now resolves the active company code to the live company UUID, scopes list/count queries by that UUID, and injects the UUID on inserts. Live RLS policies restrict employee/attendance/performance writes to owner/admin/manager/HR; payroll runs, lines and approvals use finance/HR role checks. The leave-request policy supports member submission with creator identity and HR/manager approval.

Remaining gaps: the adapter still uses the legacy `window.sb` bridge; employee self-service/team scoping and sensitive payroll-field separation need end-to-end verification; HR tables currently have no migrated business rows; no browser/JWT tests have approved the full HR lifecycle. HR and Payroll must stay disabled.

### HR schema direction

Build one company-scoped employee master and keep highly sensitive compensation/payroll details in a separately permissioned data set. Add attendance, leave requests and approvals, performance reviews, disciplinary records, payroll runs, payroll lines and payroll approvals only with explicit role separation. Employee self-service must be limited to the employee's own permitted records; managers must see only their company/team scope; HR and payroll access must be separately granted. Payroll calculations, approval transitions and finalization must be server-validated and audited. Do not trust payroll amounts, approvals or period status supplied by localStorage.

## Activation decision

Finance and HR production bridges are **not approved**. Keep the production allowlist empty. First reconcile the CRM UI bridge to the live `crm_*` contracts and complete browser-authenticated tests for Supply & Logistics. Finance's schema-backed adapter and HR's schema-backed tables are meaningful progress, not full module acceptance. Finance source-document automation, bank/tax/close workflows, HR self-service/team access, sensitive payroll isolation, and real Auth/JWT/browser role-denial tests remain required. The full V6.7 screens remain available in demo review mode only.


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


## Atomic posting and reversal procedures — 2026-10-31

Forward migrations:
- `20261031114856_add_atomic_journal_posting_and_reversals`
- `20261031115029_fix_reversal_posted_entry_immutability`

The authenticated `post_journal_entry` procedure validates an active owner/admin/manager/accountant membership, paired source identity, balanced positive debit/credit lines, active accounts belonging to the selected company, and an open fiscal period. It inserts the draft header and all lines and posts within one database transaction. The database's unique company/source index supplies duplicate-source protection when callers provide source identity.

The authenticated `reverse_journal_entry` procedure locks the original posted journal, checks that it has not already been reversed, requires an open period on the reversal date, creates a separate reversal journal with debit/credit sides swapped, and records the original journal link before posting. Posted entries remain immutable. The first rollback-only test exposed that writing the reversal link after posting conflicted with the immutable-header trigger; the follow-up migration corrected the order.

Verification: a rollback-only authenticated SQL test created temporary accounts and an open period, called the posting RPC, verified equal posted totals and poster identity, called the reversal RPC, verified the reversal totals and original-entry link, then rolled back all test rows.

Important remaining limitation: the posting RPC currently accepts a balanced source-linked journal but does **not yet independently validate the business approval state of a sales/purchase source document**. Do not wire sales or purchase auto-posting to it until source-specific validation and idempotency semantics are implemented and tested. The Finance UI remains disabled.


### 2026-11-06 transaction-cost and profitability extension

A separate `transaction_costs` table now captures factory selection/sourcing, quality assistance, dealer referral, loading, transport, handling and other transaction costs. Each row is company-scoped, records date/category/recipient/location/reference/amount, and classifies the cost as `landed_cost`, `direct_sales_cost`, or `operating_expense`. Company members can record costs; owner/admin/manager/accountant roles manage updates and deletion. No payment, receipt or supplier-payment fields are part of this register.

The Management Reporting profitability panel now calculates:
- **Landed gross profit** = net posted sales revenue − cost of goods sold from fully costed `sale_issue` stock movements (less customer returns) − additional landed costs.
- **Profit after direct sales costs** = landed gross profit − classified direct sales costs.
- Operating expenses are displayed separately and are not deducted from the direct-sales-cost measure.

Draft sales/purchase documents and unposted stock movements are excluded. The metrics remain pending until posted sales invoices and fully costed stock issue movements exist. No real transaction-cost rows have been entered yet.
