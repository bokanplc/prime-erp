# BOKAN ERP V6.7 — Draft Access-Control Matrix

Status: planning draft only; not applied to Supabase. Review against actual job duties before production.

## Rules applying to every company-owned table

- Every row must be assigned to a valid legal entity using a consistent company foreign key or validated company code.
- Users must be authenticated and have an active, non-terminated profile before accessing business records.
- The user's company membership and role must come from a protected profile/membership record, never from localStorage, editable user metadata, URL parameters, or a UI dropdown.
- RLS is required on every exposed table. Database grants must also be least-privilege. An authenticated role alone is not sufficient permission.
- For insert/update, enforce tenant and ownership rules with WITH CHECK as well as USING. Do not allow a user to move an existing row into another company.
- Do not grant ordinary users permission to change protected profile fields, payroll approvals, financial posting state, audit history, or company bank details.
- Delete rights should be exceptional. Prefer void/cancel/reversal workflows for accounting, payroll, inventory, and issued proformas.

## Initial role matrix for review

| Data domain | Sales / Junior Sales | Sales Manager | Accounting | HR | Department Manager | Company Admin |
|---|---|---|---|---|---|---|
| CRM customers and activity | Read/write assigned customers; log own activity | Read/write sales team within same company; reassign if authorized | No access unless billing requires limited customer fields | No access by default | Read own department's relevant records | Manage within assigned company |
| Opportunities and sales targets | Own records; view own target | Team pipeline and targets; manage team targets | Read-only only if required for commission calculation | No access by default | Department-scoped summary | Manage within assigned company |
| Proformas and customer billing | Create/edit drafts for permitted company; no arbitrary deletion of issued records | Approve/manage according to company policy | Read and verify totals; authorized issue/void workflow | No access | Read-only only if business requires it | Manage issuer settings and authorized records |
| Bank accounts and company master | No access | No access by default | Read only when needed for billing/payment; no unrestricted bank edits | No access | No access | Edit company-specific records with audit trail |
| AP/AR, receipts, payments, journal entries, fiscal periods | No access | No access by default | Role-specific create/read/approve/post permissions; separation of duties | No access | No access by default | Administer users/configuration, not automatically approve own transactions |
| Employees, attendance, leave | Own attendance/requests; view own records | Team-scoped attendance/leave only if assigned authority | No access except approved payroll accounting fields | Manage HR records within assigned company | Team-scoped requests for approval | User administration; sensitive HR access only if explicitly granted |
| Payroll runs, lines and approvals | No access | No access by default | Limited payroll journal/output access if authorized | Prepare payroll; cannot approve own run unless policy explicitly permits | Approval only for assigned scope if needed | Configure access; payroll data access separately granted |
| Expenses, trips, per diem | Submit own requests; view own submissions | Review assigned team submissions | Verify/post approved expenses | No access by default | Approve assigned team requests | Configure workflow; avoid self-approval |
| Inventory and deliveries | View permitted operational data; no ledger deletion | Team/operations scope as assigned | Read cost/financial fields only if needed | No access | Manage assigned operational scope | Company-scoped administration |
| Documents and storage | Access only permitted category and company | Team-scoped categories | Finance-only documents as authorized | HR-only documents as authorized | Department-scoped documents | Manage access; downloads still subject to policy |
| Profiles and roles | Read own safe profile fields only | No role editing | No role editing | No role editing by default | No role editing | Provision/disable users via controlled admin process |
| Notifications | Read own/recipient notifications | Team notifications if explicitly authorized | Own/finance-scoped notices | Own/HR-scoped notices | Department scope | Manage only authorized notification operations |
| Audit trail | No edit/delete; only limited relevant view if required | Limited relevant view | Finance audit scope | HR audit scope | Department scope | Security/audit administration |

## Canonical-model decisions still open

Do not create all of the following as parallel systems until the source is reconciled:
- `customers` vs `bokan_customers`, and `customer_logs` vs `bokan_customer_activities`
- `employees` vs `bokan_employees`
- `leave_requests` vs `bokan_leave_requests`
- `performance_reviews` vs `bokan_performance_reviews`
- `stock_entries` vs `stock_ledger` (they may represent distinct concepts, but relationship and posting rules need to be defined)
- `bokan_journal_entries`, AP/AR, receipts and payments need explicit posted/draft and reversal semantics.
- Proforma numbering must use one concurrency-safe database function. Do not retain an insecure client-side or legacy fallback as an alternate production path.

## Required negative tests before production

1. Anonymous visitor cannot read or write any business table.
2. PRIME user cannot read, edit, delete, or infer BlackRock records through direct API calls; repeat in reverse.
3. Sales user cannot change own role, company, active flag, or terminated state.
4. Inactive or terminated user cannot access business data even if a session token remains.
5. Sales user cannot access another salesperson's restricted records unless manager permission explicitly allows it.
6. HR/payroll user without payroll authority cannot read payroll amounts or approve payroll.
7. Finance user cannot alter HR-only sensitive records.
8. A user cannot change a row's company ID/code during update or insert a row under another company.
9. Bank account edits, document downloads, deletes, and approval operations are denied unless specifically authorized.
10. Invalid totals, duplicate proforma numbers, out-of-period postings, and unauthorized deletes/reversals are rejected by the database.
11. Failed network/database writes are shown as failures and are never represented as successfully saved.
12. Hosted application cannot enter mock/demo mode when credentials are missing, invalid, or the session is unauthenticated.

## Scope limitation

This matrix is a conservative starting point for review, not a final legal/organizational policy. It deliberately grants no broad access just because a user is signed in. No database changes have been made by this document.
