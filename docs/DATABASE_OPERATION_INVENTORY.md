# BOKAN ERP V6.7 — database operation inventory

Generated from static inspection of `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` on 2026-10-24.

**Purpose:** identify implementation scope for the database contract. This is not a schema, migration, or security approval. Counts are regex-based static observations; dynamic calls and related table names inside joins may need manual review.

## Current source snapshot

- Literal `.from('table')` call sites: 41
- Distinct direct table names: 41
- Additional table names passed into generic `insert`/`update`/`q`/`count` helpers: 14
- Distinct logical database table names observed across direct and helper calls: 55
- Direct operations: {"insert":36,"select":69,"update":21,"delete":16}
- Literal `localStorage.getItem/setItem/removeItem` calls: 88; unique literal keys detected: 15.
- `.select('*')` calls: 46.
- RPC names detected: `bokan_finance_close_readiness`, `bokan_save_proforma`, `next_proforma_no`.
- Storage buckets detected: `documents`.
- Legacy API base: `/api`; observed suffixes: `/auth/login`, `/auth/change-password`, `/auth/logout`, `/bootstrap`, and `/store/`.
- The source still includes a mock backend for local preview. The hosted startup path is designed to fail closed; the legacy API-dependent modules remain blocked on a hosted static site until migrated or given a real authenticated API.
- Production document upload/download and bank-account replacement remain disabled pending private Storage and atomic audited workflows.

## All direct table references

| Table | Direct references | Primary review area |
|---|---:|---|
| `bokan_ap_bills` | 1 | Accounts payable |
| `bokan_ap_payments` | 1 | Accounts payable |
| `bokan_ar_invoices` | 1 | Accounts receivable |
| `bokan_ar_receipts` | 1 | Accounts receivable |
| `bokan_attendance_records` | 1 | HR / attendance |
| `bokan_customer_activities` | 1 | CRM |
| `bokan_customer_assignments` | 1 | CRM |
| `bokan_customers` | 5 | CRM; reconcile with legacy customers |
| `bokan_delivery_orders` | 1 | Logistics |
| `bokan_employees` | 1 | HR; reconcile with legacy employees |
| `bokan_fiscal_periods` | 1 | Accounting controls |
| `bokan_journal_entries` | 1 | General ledger |
| `bokan_leave_requests` | 1 | HR; reconcile with legacy leave_requests |
| `bokan_payroll_approvals` | 1 | Payroll approvals |
| `bokan_payroll_lines` | 1 | Payroll-sensitive |
| `bokan_payroll_runs` | 1 | Payroll-sensitive |
| `bokan_performance_reviews` | 1 | HR; reconcile with legacy performance_reviews |
| `bokan_sales_opportunities` | 1 | Sales pipeline |
| `bokan_salespeople` | 1 | Sales assignment/identity |
| `bokan_shipments` | 1 | Logistics |
| `companies` | 3 | Legal entity master data |
| `company_bank_accounts` | 3 | Bank details; restrict writes |
| `custom_terms` | 2 | Commercial terms |
| `customer_billings` | 3 | Customer financial data |
| `customer_logs` | 11 | CRM and activity history |
| `customers` | 13 | Customer master; tenant isolation required |
| `disciplinary_actions` | 5 | Sensitive HR data |
| `documents` | 6 | Document metadata and access control |
| `employees` | 6 | Employee master; HR-sensitive |
| `expenses` | 8 | Finance-sensitive |
| `leave_requests` | 6 | HR-sensitive |
| `notifications` | 2 | Restrict by recipient |
| `per_diem_requests` | 6 | Employee expense/approval data |
| `performance_reviews` | 5 | Sensitive HR data |
| `profiles` | 9 | Identity, role, and company profile |
| `proformas` | 4 | Commercial data and financial validation |
| `sales_targets` | 4 | Sales performance data |
| `stock_entries` | 9 | Inventory movement/source records |
| `stock_ledger` | 7 | Inventory ledger |
| `trip_plans` | 5 | Staff travel and expense data |
| `visit_reports` | 4 | Sales/CRM |

## Literal localStorage keys detected

- `bokan_active_company_context`
- `bokan_sales_lifecycle_v1`
- `customer_logs`
- `customers`
- `prime_customer_logs`
- `prime_customers`
- `prime_proforma_requests`
- `prime_release_environment`
- `prime_release_last`
- `prime_release_role`
- `prime_v22_corporate`
- `prime_v27_ops`
- `prime_v28_control`
- `prime_v40_transactions`
- `prime_v53_lastscan`

These are not necessarily all business records; some may be release flags or UI context. They still need a per-module decision: migrate to canonical protected database tables, keep as non-sensitive UI preference, or remove. Client-controlled role/company context must never authorize access.

## Important reconciliation points

- Both legacy and `bokan_*` models appear for employees, leave requests, performance reviews, and customers/CRM. Do not create parallel tables by name alone; determine the intended canonical model and migrate deliberately.
- Many legacy reads use `select('*')`, so field-level compatibility cannot be inferred from narrow selects alone.
- Some operations include nested relationships such as `customers(customer_name)`; foreign keys and PostgREST relationship names must match.
- Profile role and company code affect the UI, but UI filtering is not a security boundary. Database RLS must enforce company isolation and permitted operations.
- The new `bokan_save_proforma` RPC draft is intended to allocate the number, calculate VAT-inclusive totals/withholding, snapshot issuer details, and insert a revision in one transaction. It is design-only and has **not** been applied or integration-tested.
- The legacy `next_proforma_no` call remains in the non-production preview path; it must not be used by the hosted production path.
- The source still contains public Storage URL helper references in legacy code. The sanitized release candidate removes the helper path and blocks document access until private signed downloads exist.

## Recommended implementation sequence

1. Reconcile canonical legacy/new table models and map every module's payload fields and joins.
2. Validate the first-slice proforma schema and atomic save RPC on an isolated disposable database, including concurrent insert and revision tests.
3. Define constraints, indexes, foreign keys, audit fields, and deletion/retention policy for each remaining module.
4. Write reviewed SQL migrations in version control; do not apply the draft to the current Supabase project until test results and access design are reviewed.
5. Enable RLS and add operation-specific policies, including company and role checks.
6. Implement private Storage and a secure route for the legacy `/api/*` dependency or complete a module-by-module migration to Supabase.
7. Test as anonymous user, PRIME user, BlackRock user, and admin before enabling production configuration.


## Additional table names passed through generic data-access helpers

The direct `.from('table')` scan alone misses table names passed to the shared production helper functions. Static review found these 14 additional logical database table names; their complete payload/relationship mapping is still outstanding:

- `bokan_factories`
- `bokan_warehouses`
- `bokan_purchase_requests`
- `bokan_purchase_request_lines`
- `bokan_purchase_orders`
- `bokan_purchase_order_lines`
- `bokan_shipment_containers`
- `bokan_goods_receipts`
- `bokan_inventory_movements`
- `bokan_stock_reservations`
- `bokan_delivery_order_lines`
- `bokan_delivery_events`
- `bokan_logistics_exceptions`
- `bokan_inventory_balances`

These names are passed to generic CRUD helpers in the supply/procurement/logistics production bridge. They are not in the current Supabase schema, and the bridge must remain disabled until each table's company scope, foreign keys, payload fields, role permissions, atomic workflow, and test cases are designed. The updated static audit now tracks both the 41 direct table names and the generic helper table names.


## Proforma arithmetic consistency check (2026-10-24)
The print layout's displayed order is subtotal before VAT, VAT, discount, grand total. The production UI and first-slice trusted SQL draft now use a reconciled formula: pre-discount VAT-exclusive subtotal + pre-discount VAT − VAT-inclusive discount = grand total. Withholding uses the final grand total. Regression tests cover the same expected example: gross ETB 11,500, discount ETB 1,150, subtotal ETB 10,000, VAT ETB 1,500, grand total ETB 10,350, withholding ETB 310.50, net payable ETB 10,039.50. Confirm discount tax treatment with an Ethiopian accountant before live use.
