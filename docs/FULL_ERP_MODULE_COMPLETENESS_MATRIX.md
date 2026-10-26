# BOKAN ERP V6.7 — Full Module Completeness Matrix

**Generated from the staged source and first-slice schema draft on 2026-10-24.**  
**Status: STOP-SHIP. This is a readiness inventory, not production approval.**

## Current coverage

- Distinct logical table names referenced by the full V6.7 source: **55**
- Table definitions in the only current schema draft: **5**
- Table definitions still missing: **50**
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
| `custom_terms` | Company-scoped commercial terms; authenticated company users may add terms, but client updates/deletes are not granted |
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


## Live Supabase cross-check — 2026-10-26

A current read-only inspection of the connected Supabase project has now found an applied 12-table sales/procurement/inventory foundation and 15 recorded migrations. This differs from the earlier historical statements in this matrix that the live project has no applied tables or migrations; the earlier statement was true at its check date, but is stale now.

Observed live public tables (RLS reported enabled on each): companies (2 rows), company_memberships (2), customers (0), products (0), sales_documents (0), sales_document_items (0), suppliers (0), purchase_documents (0), purchase_document_items (0), stock_movements (0), sales_payments (0), supplier_payments (0).

Important counting distinction: the reported 55 source-referenced logical names and 50 missing table definitions refer to comparison against the current five-table first-slice schema draft. Those counts do not mean that the live project has only five tables or that exactly 50 live tables are missing. Some business areas overlap with the live 12-table foundation, but the full source-to-live contract, exact column compatibility, authorization, and workflow coverage have not yet been proven.

The live identity schema uses companies plus company_memberships (company_id/user_id/role/is_active), while the first-slice Proforma candidate defines companies plus profiles (company_code/role). Do not apply that candidate as-is to live Supabase. First reconcile tenant identity/membership, proforma ownership/numbering, grants/RLS, and live migration SQL.

See docs/LIVE_SCHEMA_RECONCILIATION_2026-10-26.md and the matching checkpoint appended to DEPLOYMENT_STATUS.md for the complete read-only facts, the 15 migration names, current Vercel/Cloudflare evidence, and safe next work.

Release decision remains STOP-SHIP. No business module is approved for hosted production; the app must remain disabled until canonical models, full access controls, Auth/Data API/browser tests, private Storage, and persistence/recovery gates pass.

## Automated completeness-gate interpretation — 2026-10-26

The CI readiness audit intentionally exits successfully while production is disabled; this means it can report blockers without breaking every staging documentation/source commit. It is not a green release verdict. The latest run's log explicitly reported STOP-SHIP for 50 table definitions missing from the five-table schema draft and for all five legacy /api endpoint groups missing. It also reported zero remaining matches in the tracked raw-HTML-sink patterns, which is useful progress but not a substitute for real authorization/runtime testing.

The workflow has no step that runs a real browser against the connected Supabase project, tests Auth/JWT/Data API against the live project, or validates a complete migrated module set. The PostgreSQL tests run in an ephemeral CI service. Therefore do not interpret the successful jobs as proof that the live Proforma, CRM, HR, inventory, finance, payroll, or document flows are operational.

Recommended gate improvement: keep the current disabled-build tests, and later add a separate, explicitly non-production integration workflow with disposable test users/project credentials, real browser automation, and direct company-crossing / role-denial assertions. Do not use production credentials or business records in CI.