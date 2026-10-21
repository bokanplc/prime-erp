# BOKAN ERP V6.7 — Source Data-Access Coverage

Review date: 2026-10-21  
Source reviewed: `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` on `deploy/secure-staging`.

This is a lexical inventory of direct Supabase `.from('table').operation(...)` calls. It is useful for review coverage, but it is not a complete parser, proof of reachability, or a substitute for RLS tests. Counts can include calls in different code paths and should not be interpreted as transaction counts.

## Direct table operation counts

| Table | Source area classification | Select | Insert | Update | Upsert | Delete | Other |
|---|---|---:|---:|---:|---:|---:|---:|
| `bokan_ap_bills` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_ap_payments` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_ar_invoices` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_ar_receipts` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_attendance_records` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_customer_activities` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_customer_assignments` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_customers` | New BOKAN bridge | 2 | 1 | 2 | 0 | 0 | 0 |
| `bokan_delivery_orders` | New BOKAN bridge | 1 | 0 | 0 | 0 | 0 | 0 |
| `bokan_employees` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_fiscal_periods` | New BOKAN bridge | 1 | 0 | 0 | 0 | 0 | 0 |
| `bokan_journal_entries` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_leave_requests` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_payroll_approvals` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_payroll_lines` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_payroll_runs` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_performance_reviews` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_sales_opportunities` | New BOKAN bridge | 0 | 1 | 0 | 0 | 0 | 0 |
| `bokan_salespeople` | New BOKAN bridge | 0 | 0 | 1 | 0 | 0 | 0 |
| `bokan_shipments` | New BOKAN bridge | 1 | 0 | 0 | 0 | 0 | 0 |
| `companies` | Legacy/shared UI | 1 | 0 | 2 | 0 | 0 | 0 |
| `company_bank_accounts` | Legacy/shared UI | 1 | 1 | 0 | 0 | 1 | 0 |
| `custom_terms` | Legacy/shared UI | 1 | 1 | 0 | 0 | 0 | 0 |
| `customer_billings` | Legacy/shared UI | 1 | 1 | 0 | 0 | 1 | 0 |
| `customer_logs` | Legacy/shared UI | 8 | 2 | 0 | 0 | 1 | 0 |
| `customers` | Legacy/shared UI | 10 | 1 | 2 | 0 | 0 | 0 |
| `disciplinary_actions` | Legacy/shared UI | 2 | 1 | 1 | 0 | 1 | 0 |
| `documents` | Legacy/shared UI | 1 | 1 | 0 | 0 | 1 | 3 |
| `employees` | Legacy/shared UI | 3 | 1 | 1 | 0 | 1 | 0 |
| `expenses` | Legacy/shared UI | 5 | 1 | 1 | 0 | 1 | 0 |
| `leave_requests` | Legacy/shared UI | 2 | 1 | 2 | 0 | 1 | 0 |
| `notifications` | Legacy/shared UI | 1 | 1 | 0 | 0 | 0 | 0 |
| `per_diem_requests` | Legacy/shared UI | 2 | 1 | 2 | 0 | 1 | 0 |
| `performance_reviews` | Legacy/shared UI | 2 | 1 | 1 | 0 | 1 | 0 |
| `profiles` | Legacy/shared UI | 8 | 0 | 1 | 0 | 0 | 0 |
| `proformas` | Legacy/shared UI | 2 | 2 | 0 | 0 | 1 | 0 |
| `sales_targets` | Legacy/shared UI | 1 | 1 | 1 | 0 | 1 | 0 |
| `stock_entries` | Legacy/shared UI | 6 | 1 | 1 | 0 | 1 | 0 |
| `stock_ledger` | Legacy/shared UI | 4 | 1 | 1 | 0 | 1 | 0 |
| `trip_plans` | Legacy/shared UI | 2 | 1 | 1 | 0 | 1 | 0 |
| `visit_reports` | Legacy/shared UI | 1 | 1 | 1 | 0 | 1 | 0 |

## RPC and Storage surface

- RPCs referenced: `bokan_next_proforma_number`, `next_proforma_no`, `bokan_finance_close_readiness`.
- Storage bucket referenced: `documents`.
- Document upload code calls `getPublicUrl(path)`; this is a privacy blocker for any confidential document until replaced with a private-access design or explicitly proven safe for public files.
- The source contains both legacy UI data access and newer BOKAN bridge code. Secure only one side and the other remains a possible access path.

## Review priorities

1. **Every legacy/shared UI table** must have company ownership defined and be covered by RLS. Current legacy operations include updates and deletes for business records.
2. **Every new BOKAN bridge table** needs explicit tenant ownership, profile membership checks, role-specific permissions, and tested insert/update checks.
3. **Profiles** must not permit ordinary users to update their own role or company membership.
4. **Proformas** need one canonical model, one numbering RPC, uniqueness constraints, and auditable issue/void semantics.
5. **Documents** need private object storage and database metadata policies that agree with object-level policies.
6. **Multi-step writes** (e.g., customer + activity log, document object + metadata, proforma + numbering) should be transactional where partial completion would leave inconsistent business state.
7. **Reads with `select('*')`** should be reduced to required fields after schema stabilization, especially for HR, payroll, finance and documents.

## No changes to production

No schema, policy, grant, storage setting, migration, or deployment was changed as part of this inventory.
