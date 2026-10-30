# BOKAN ERP V6.7 — Full production migration workplan

**Status:** active engineering plan; staging only. This is not a claim of production readiness.

## Non-negotiable project scope

Migrate the existing full BOKAN ERP V6.7 application as one integrated ERP for BlackRock Investment PLC and Prime Investment Group. Proforma is one workflow inside the ERP, not a standalone application or separate release. Withholding is not a required Proforma feature and must not block the full ERP migration.

Keep production mode, reviewed-module allowlist, and live schema changes disabled until each module passes its acceptance gates. Do not merge the staging branch into main or deploy a production release as a shortcut.

## Verified live foundation

The connected Supabase project currently has 12 public tables with RLS enabled:
- companies and company_memberships
- customers and products
- sales_documents and sales_document_items
- suppliers
- purchase_documents and purchase_document_items
- stock_movements
- sales_payments and supplier_payments

The migration history contains 15 records. Four historical SQL bodies are not currently present in source control. The existing company-membership model is the tenant and authorization source of truth. Do not replace it with a second profiles/company-code model.

## Work sequence

### 0. Preserve and reconcile the foundation
- Recover the exact four missing historical migration SQL files from repository history, backups, or Supabase migration artifacts.
- If exact originals cannot be recovered, create a clearly labeled live-schema baseline from catalog inspection; never invent historical migration bodies.
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
- Map purchase request/order, shipment, goods receipt, warehouse, reservation, delivery and exception payloads.
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
- The CRM bridge references customer activity, assignment, salesperson, and opportunity tables absent from the live 12-table foundation. Its current reassignment sequence is multi-step and is not atomic.
- Procurement/logistics, finance, HR/payroll, documents, and notifications require canonical schema and trusted operations.
- The four missing historical migration bodies remain a migration-source gap.
- No business module is currently approved for hosted production; the production allowlist remains empty.

## Immediate next engineering tasks

1. Finish the migration-source recovery and live catalog parity audit.
2. Produce exact field-level contracts for CRM and procurement from all V6.7 reads/writes.
3. Design disposable PostgreSQL migrations and negative security tests for the canonical CRM model.
4. Only after those pass, prepare a forward-only Supabase migration for review; do not apply it automatically.
