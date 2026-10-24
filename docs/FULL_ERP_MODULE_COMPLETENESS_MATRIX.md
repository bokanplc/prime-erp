# BOKAN ERP V6.7 — Full Module Completeness Matrix

**Generated from the staged source and first-slice schema draft on 2026-10-24.**  
**Status: STOP-SHIP. This is a readiness inventory, not production approval.**

## Current coverage

- Distinct logical table names referenced by the full V6.7 source: **55**
- Table definitions in the only current schema draft: **4**
- Table definitions still missing: **51**
- Required legacy API endpoint groups: login, change-password, logout, bootstrap, store. These are not implemented in the repository's expected Cloudflare Pages Functions paths.
- Production mode: disabled.
- Full ERP data readiness: disabled.
- Supabase production project: no application tables or migrations applied.

The full ERP is **not** ready for deployment as a working application. A green source/test workflow means the reviewed source guards and the first-slice proforma schema tests passed; it does not mean the other ERP modules have database persistence.

## Schema-covered first slice

| Table | Scope in current draft |
|---|---|
| `companies` | PRIME and BlackRock issuer master, legal identity and TIN |
| `profiles` | Supabase Auth-linked user profile, role, company code, active/terminated status |
| `company_bank_accounts` | Issuer bank accounts; read-only for browser users until atomic audited maintenance exists |
| `proformas` | Proforma header/items/snapshots, versioning, totals, numbering, trusted save RPC |

The draft has passed disposable PostgreSQL tests for RLS/grants, tenant read isolation, inactive/terminated profile denial, financial totals, malformed input rejection, and concurrent numbering. It has **not** been applied to the live Supabase project.

## Referenced tables still missing schema

- `bokan_ap_bills`
- `bokan_ap_payments`
- `bokan_ar_invoices`
- `bokan_ar_receipts`
- `bokan_attendance_records`
- `bokan_customer_activities`
- `bokan_customer_assignments`
- `bokan_customers`
- `bokan_delivery_events`
- `bokan_delivery_order_lines`
- `bokan_delivery_orders`
- `bokan_employees`
- `bokan_factories`
- `bokan_fiscal_periods`
- `bokan_goods_receipts`
- `bokan_inventory_balances`
- `bokan_inventory_movements`
- `bokan_journal_entries`
- `bokan_leave_requests`
- `bokan_logistics_exceptions`
- `bokan_payroll_approvals`
- `bokan_payroll_lines`
- `bokan_payroll_runs`
- `bokan_performance_reviews`
- `bokan_purchase_order_lines`
- `bokan_purchase_orders`
- `bokan_purchase_request_lines`
- `bokan_purchase_requests`
- `bokan_sales_opportunities`
- `bokan_salespeople`
- `bokan_shipment_containers`
- `bokan_shipments`
- `bokan_stock_reservations`
- `bokan_warehouses`
- `custom_terms`
- `customer_billings`
- `customer_logs`
- `customers`
- `disciplinary_actions`
- `documents`
- `employees`
- `expenses`
- `leave_requests`
- `notifications`
- `per_diem_requests`
- `performance_reviews`
- `sales_targets`
- `stock_entries`
- `stock_ledger`
- `trip_plans`
- `visit_reports`

Some duplicate-looking legacy/new models must be reconciled before their tables are created. Do not blindly create all names independently.

## Required backend still missing

The legacy adapter calls:
- `/api/auth/login`
- `/api/auth/change-password`
- `/api/auth/logout`
- `/api/bootstrap`
- `/api/store/*`

The current repository does not implement the corresponding Cloudflare Pages Functions groups. Static Pages hosting will not supply them automatically. The hosted adapter is intentionally fail-closed until those modules are migrated to the Supabase-backed path or a properly authenticated API is built.

## What the readiness gate does

`scripts/audit-erp-release-readiness.mjs` is now part of CI. It prints the missing schema/API coverage while production remains disabled. If either `PRODUCTION_MODE` or `FULL_ERP_DATA_READY` is changed to `true` while blockers remain, it fails the build.

## Release condition

Do not turn on full ERP mode or deploy this candidate as a functioning production ERP until:
1. Canonical data models and company-membership rules are approved.
2. Each enabled module has a complete schema, grants, RLS, constraints and trusted write paths.
3. The legacy API dependency is removed or implemented securely.
4. Private document storage and signed downloads are implemented.
5. Real browser/Auth/Data API tests pass for both PRIME and BlackRock.
6. Business records are reconciled and export/recovery has been rehearsed.
