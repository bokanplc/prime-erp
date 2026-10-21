# BOKAN ERP V6.7 — database operation inventory

Generated from static inspection of `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` on 2026-10-21.

**Purpose:** identify implementation scope for the database contract. This is not a schema, migration, or security approval. Counts are regex-based static observations; dynamic calls and related table names inside joins may need manual review.

## Summary
- Direct `.from('table')` calls: 146
- Distinct direct table names: 41
- `localStorage` string references: 96 (must be reviewed; some may be preferences rather than business records)
- The source includes an in-memory mock backend and uses it when production configuration is absent.
- The source contains a review-mode UI and comments that authentication was bypassed in the review build. Do not deploy this artifact for business use until production auth is enforced.

## Direct table references and rough call counts

| Table | Direct references | Notes |
|---|---:|---|
| profiles | 9 | Identity/role/company profile; highest priority for secure bootstrap |
| customers | 13 | Customer records; tenant isolation required |
| customer_logs | 11 | Activity/CRM logs; joins reference customers |
| stock_entries | 9 | Inventory movement/source records |
| employees | 6 | Employee master; HR-sensitive |
| documents | 6 | Uploaded/document metadata and access control |
| leave_requests | 6 | HR-sensitive |
| expenses | 8 | Finance-sensitive |
| stock_ledger | 7 | Inventory ledger |
| per_diem_requests | 6 | Employee expense/approval data |
| performance_reviews | 5 | HR-sensitive |
| proformas | 5 | Customer/commercial data; financial calculation validation required |
| trip_plans | 5 | Staff travel and expense data |
| disciplinary_actions | 5 | Highly sensitive HR data |
| visit_reports | 4 | Sales/CRM |
| sales_targets | 4 | Sales performance data |
| company_bank_accounts | 3 | Bank account details; restrict writes to authorized roles |
| companies | 3 | Legal entity master data |
| customer_billings | 3 | Customer financial data |
| notifications | 2 | User-targeted data; restrict by recipient |
| custom_terms | 2 | Commercial document terms |
| bokan_customers | 5 | Newer CRM model; reconcile with legacy `customers` |
| bokan_ap_bills | 1 | Accounts payable |
| bokan_ap_payments | 1 | Accounts payable |
| bokan_ar_invoices | 1 | Accounts receivable |
| bokan_ar_receipts | 1 | Accounts receivable |
| bokan_attendance_records | 1 | HR |
| bokan_customer_activities | 1 | CRM |
| bokan_customer_assignments | 1 | CRM |
| bokan_delivery_orders | 1 | Logistics |
| bokan_employees | 1 | HR; reconcile with legacy `employees` |
| bokan_fiscal_periods | 1 | Accounting period controls |
| bokan_journal_entries | 1 | General ledger |
| bokan_leave_requests | 1 | HR; reconcile with legacy `leave_requests` |
| bokan_payroll_approvals | 1 | Payroll approval |
| bokan_payroll_lines | 1 | Payroll-sensitive |
| bokan_payroll_runs | 1 | Payroll-sensitive |
| bokan_performance_reviews | 1 | HR; reconcile with legacy `performance_reviews` |
| bokan_sales_opportunities | 1 | Sales pipeline |
| bokan_salespeople | 1 | Sales assignment/identity |
| bokan_shipments | 1 | Logistics |
| bokan_fiscal_periods | 1 | Accounting controls |
| bokan_delivery_orders | 1 | Logistics |

## Important reconciliation points
- Both legacy and `bokan_*` models appear in the source for employees, leave requests, performance reviews, and customers/CRM. Do not create parallel tables by name alone; determine the intended canonical model and migrate/bridge deliberately.
- Many legacy reads use `select('*')`, so field-level compatibility cannot be inferred from narrow selects alone.
- Some operations include nested relationships such as `customers(customer_name)`; foreign keys and PostgREST relationship names must match.
- Profile role and company code affect the UI, but UI filtering is not a security boundary. Database RLS must enforce company isolation and permitted operations.
- A mock backend can make UI workflows appear to save successfully even when no database write occurred. Production must never silently use it.

## Recommended next implementation sequence
1. Trace each table operation to the payload objects and required columns.
2. Decide canonical legacy/new table models and update the source consistently.
3. Define constraints, indexes, foreign keys, audit fields, and deletion/retention policy.
4. Write SQL migrations in version control.
5. Enable RLS and add operation-specific policies, including company and role checks.
6. Test as anonymous user, PRIME user, BlackRock user, and admin before enabling production config.
