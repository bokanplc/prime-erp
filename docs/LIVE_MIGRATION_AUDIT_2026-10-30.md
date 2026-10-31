# BOKAN ERP V6.7 — live migration checkpoint (2026-10-30)

This is a read-only reconciliation of the connected GitHub, Supabase, and Vercel state. It supersedes older status notes that still describe an empty Supabase database. It does not authorize production deployment.

## Connected services

- GitHub repository: `bokanplc/prime-erp` (private repository; staging work is on `deploy/secure-staging`).
- Supabase project: `BOKAN ERP`, ref `kafiwnuynjemufnankvi`, status `ACTIVE_HEALTHY`, region `eu-central-1`.
- Vercel project search for `bokan`: no matching project returned. Do not assume Vercel is connected or deployed.

## Verified Supabase progress

- 15 migration records are present (latest recorded version: `20261026094634`).
- 12 public application tables exist:
  - `companies`
  - `company_memberships`
  - `customers`
  - `products`
  - `sales_documents`
  - `sales_document_items`
  - `suppliers`
  - `purchase_documents`
  - `purchase_document_items`
  - `stock_movements`
  - `sales_payments`
  - `supplier_payments`
- RLS is enabled on all 12 public tables.
- 42 public-schema RLS policies were counted.
- Two active company records exist: `BLACKROCK` (BlackRock Investment PLC) and `PRIME` (Prime Investment Group).
- Eight public-schema routines and zero Storage buckets were counted.
- Current database includes initial multi-company sales, purchasing, inventory, payment, stock-posting, approval, reconciliation, and indexing foundations. This is a meaningful advance over the 2026-10-21 status notes.

## Important limitations and next work

- The source operation inventory identifies 57 logical table names across direct calls and generic CRUD helpers. Only 12 are currently present in the public schema. The remaining source modules are not fully backed by the live database.
- The current 12-table foundation does not yet constitute the complete ERP: HR/payroll, full CRM, general ledger, AR/AP, logistics, documents/private storage, and other modules remain to be reconciled and implemented.
- No Storage buckets exist; private document upload/download is therefore not ready.
- The legacy `/api/*` integration family remains an architectural blocker for older modules unless migrated to the secured Supabase model or backed by a separate authenticated API.
- Production mode and `FULL_ERP_DATA_READY` must remain disabled until all modules, identity provisioning, tenant/role policies, trusted transaction boundaries, browser integration, and negative security tests pass.
- Do not publish the review HTML or sanitized static candidate as if it were a functioning ERP. Do not merge the draft review PR or deploy as a release based on this checkpoint.

## Recommended next sequence

1. Reconcile the 12 live tables and 15 applied migrations against the repository's migration files and confirm no migration drift.
2. Run authenticated negative tests for cross-company reads/writes and role boundaries against Supabase JWT/Data API behavior (not only disposable PostgreSQL).
3. Finish the next source-to-schema slice by mapping each remaining module's fields, joins, company key, lifecycle, and trusted writes.
4. Implement private Storage and secure document access.
5. Migrate or replace legacy `/api/*` calls module by module.
6. Run end-to-end browser tests for the full V6.7 workflows before enabling production mode.

## Verification notes

All counts above came from connected service reads on 2026-10-30. RLS being enabled and policies existing do not, by themselves, prove the policies are correct. No database changes, Auth changes, Storage changes, paid-plan upgrades, merges, or deployments were made during this audit.
