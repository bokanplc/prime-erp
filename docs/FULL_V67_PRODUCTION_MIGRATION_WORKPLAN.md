# BOKAN ERP V6.7 — Full production migration workplan

**Status:** active engineering plan; staging only. This is not a claim of production readiness.

## Non-negotiable project scope

Migrate the existing full BOKAN ERP V6.7 application as one integrated ERP for BlackRock Investment PLC and Prime Investment Group. Proforma is one workflow inside the ERP, not a standalone application or separate release. Withholding is not a required Proforma feature and must not block the full ERP migration.

Keep production mode and the reviewed-module allowlist disabled until each module passes its acceptance gates. Forward-only live schema migrations may be applied when source-controlled, tested, company-scoped and explicitly verified. Do not merge the staging branch into main or deploy a production release as a shortcut.

## Verified live foundation

The connected Supabase project currently has 23 public base tables, all 23 with RLS enabled, 63 public RLS policies, two operational views, and 20 recorded migrations. The live foundation now includes:
- Multi-company identity and membership, customers and products.
- Sales documents/items, payments, suppliers, purchase documents/items, stock movements and supplier payments.
- Company-scoped Proforma settings, bank accounts, custom terms and saved Proformas.
- Company-scoped CRM assignments, assignment events, activities, opportunities and after-sales tasks.
- Company-scoped Supply & Logistics inbound shipment plans and delivery controls.

Thirteen timestamped SQL files are tracked under `supabase/migrations`; the three newer applied Proforma/CRM SQL bodies are archived under `supabase/candidates`. Four older historical SQL bodies remain unrecovered by choice and must not block forward migration. The existing company-membership model is the tenant and authorization source of truth. Do not replace it with a second profiles/company-code model.

## Work sequence

### 0. Preserve and reconcile the foundation
- Accept the four historical SQL bodies as an existing source-control gap; do not spend migration time attempting recovery or inventing historical migration bodies.
- Preserve a clearly labeled current-schema baseline later if it becomes necessary for reproducible environment setup.
- Compare constraints, indexes, triggers, views, functions, grants, and RLS against the live catalog before any forward migration.
- Preserve existing operational records and verify company isolation for both legal entities.

### 1. Identity, company context, and access
- Test real Supabase Auth sign-in/out, session refresh, company switching, inactive membership denial, and role denial.
- Derive all access from authenticated user and active company_memberships; localStorage company selection is only a UI hint.
- Add trusted provisioning and audited membership management before enabling role administration.
- Keep unsupported roles denied until their complete least-privilege navigation and database policy contracts are approved.

### 2. Core sales and CRM
- Keep existing customers/products/sales_documents/sales_document_items as canonical where compatible.
- Map the V6.7 CRM payloads for customer profiles, activities, salesperson assignments, opportunities, targets, and visit reports.
- Reconcile legacy customer stores with BOKAN-prefixed stores; do not create duplicate parallel customer masters.
- Make customer reassignment a single database transaction/RPC that updates the current assignment and writes assignment history atomically.
- Add company/salesperson foreign keys, RLS, audit fields, and duplicate/cross-company/invalid-payload tests.
- Validate draft, approval, posting, payment, and document history as one connected sales lifecycle.

### 3. Procurement, receiving, inventory, and logistics
- Extend existing suppliers, purchase documents/items, stock movements, and supplier payments rather than creating competing purchasing models.
- First Supply & Logistics slice is now applied: company-scoped `supply_shipments` and `delivery_orders` persist inbound shipment plans and customer delivery controls with RLS, company membership checks, role-scoped writes, quantity constraints and indexes.
- The V6.7 Supply & Logistics Control Tower bridge now reads/writes those two live tables using the authenticated active company UUID; production-mode errors do not fall back to local sample data. Sales-demand forecasting, warehouse reservations, goods receipt/stock posting integration, shipment containers and logistics exceptions remain separate work.
- Make receiving and stock posting atomic, idempotent, reversible through controlled reversal records, and protected against negative/duplicate movement.
- Verify product, supplier, warehouse, and company ownership at the database boundary.

### 4. Finance
- Reconcile AR/AP, receipts/payments, cash/bank, chart of accounts, journal entries, fiscal periods, approvals, reconciliation and close controls into one canonical ledger/subledger model.
- Require balanced journal posting, period locks, immutable posted records, allocations, and reversal workflows.
- Do not treat browser-local finance summaries or close flags as accounting records.
- Proforma is integrated into this lifecycle; no separate standalone Proforma deployment.

### 5. HR and payroll
- Select one canonical employee, attendance, leave, performance, discipline, payroll, and approval model.
- Separate employee self-service, manager access, HR administration, payroll preparation, and payroll approval.
- Payroll calculations and approvals must be server-validated and audited; no trusted payroll state in localStorage.
- Add sensitive-data and cross-company denial tests before enabling any HR/payroll tab.

### 6. Documents, notifications, quality, and controls
- Implement private Storage buckets and company/category-scoped object policies, metadata lifecycle, and expiring signed downloads.
- Move shared notifications, exceptions, quality issues, audit events, reconciliation and period-control evidence to server-side records.
- Keep release checklists and UI-only hints explicitly non-authoritative.

## Module acceptance gate

A module is not production-ready until all are true:
1. Exact UI payload/read contract and canonical schema are documented.
2. Forward-only SQL migration is source-controlled and reviewed.
3. RLS, grants, foreign keys, constraints, and indexes enforce company and role boundaries.
4. Multi-step operations use trusted transactional RPCs or equivalent atomic server operations.
5. Tests cover anonymous, wrong-role, inactive membership, cross-company, invalid payload, duplicates, concurrency, and rollback/reversal.
6. Real Supabase Auth/JWT/Data API and browser create/edit/reload tests pass.
7. Any existing browser-local data has an explicit export/migration decision.
8. Sanitized release build and CI checks pass.

## Current stop-ship findings

- The full application still has multiple browser-local modules.
- The current CRM browser bridge still references `bokan_*` tables while the live database uses the company-scoped `crm_*` contracts; this UI mismatch must be reconciled before CRM activation.
- Supply & Logistics now has a first live persistence slice, but the full procurement/receiving/reservation/delivery-exception lifecycle is not yet migrated.
- Finance, HR/payroll, documents, notifications and the remaining operational modules require canonical schema and trusted operations.
- The four missing historical migration bodies remain a documented source-control gap and are explicitly not a blocker for forward migration.
- No business module is currently approved for hosted production; the production allowlist remains empty.

## Immediate next engineering tasks

1. Complete real authenticated browser read/write/reload and cross-company denial tests for the new Supply & Logistics slice before enabling its production tab.
2. Reconcile the CRM UI bridge to the existing `crm_*` live schema and test the manager-only reassignment RPC.
3. Finance & HR local-data paths have now been mapped in `docs/FINANCE_HR_DATA_PATH_AUDIT_2026-10-31.md`; next design the Finance chart-of-accounts, journal, subledger and period-control contracts around existing approved sales/purchase source documents.
4. Build the HR employee/attendance/leave/payroll schema with sensitive-data role separation after the Finance foundation; keep all production tabs disabled until each acceptance gate passes.
