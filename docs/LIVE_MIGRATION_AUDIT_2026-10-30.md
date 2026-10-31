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


## Follow-up findings and work — 2026-10-30

### Migration source-control gap confirmed

The 15 live migration records are not all recoverable from Git. The repository contains 11 matching executable SQL migration files. These four historical SQL bodies are absent from all searched Git history and must not be reconstructed as if they were exact originals:

- `20261025065910_initial_multi_company_sales_foundation`
- `20261025072547_revoke_unauthenticated_erp_table_access`
- `20261025124247_add_missing_foreign_key_indexes`
- `20261025124312_atomic_sales_document_creation`

The existing `docs/LIVE_MIGRATION_SOURCE_GAP.md` documents this. The correct recovery path is an authoritative backup/export or a clearly labeled current-schema baseline snapshot, never a fabricated backdated migration.

### CRM candidate hardening

The staged CRM candidate now denies direct assignment updates and requires active same-company owners for opportunity and after-sales task ownership. Update privileges are column-scoped so ordinary CRM users cannot rewrite tenant/customer/creator identity fields. Additional disposable PostgreSQL assertions cover direct assignment writes and sales-user ownership transfers. See `docs/CRM_SECURITY_HARDENING_2026-10-30.md`.

This remains candidate-only. It has not been applied to live Supabase, and the CRM module remains disabled pending CI, real Supabase JWT/Data API tests, and browser persistence tests.

### Deployment status qualification

The Vercel commit status on the latest CRM test commit reported success, but this is not proof that the complete V6.7 application is deployed or production-ready. A separate Vercel deployment-list request returned a 403 for the BOKAN team scope, so current deployment state could not be independently verified in this pass.


## Migration progress update — 2026-10-31

The full V6.7 review artifact is now built and deployed on Vercel from `deploy/secure-staging` using the branch-specific review build. The build log confirms the full staging application was packaged in sample-data-only mode; no production secrets or Supabase credentials are included in the review artifact.

Two additive backend foundations were applied to live Supabase:

- `20261031080833_add_company_scoped_proforma_foundation`: company Proforma settings, bank-account snapshots, custom terms, Proforma records, and authenticated-only atomic save/settings RPCs.
- `20261031081151_add_company_scoped_crm_foundation`: CRM assignments, immutable assignment events, activities, opportunities, after-sales tasks, company-scoped RLS, and a guarded manager-only reassignment RPC.
- `20261031081422_restrict_crm_assignment_writes_to_rpc`: revokes default/anonymous CRM table grants; assignment and history writes are RPC-only.

Live verification confirms 21 public application tables have RLS enabled. Direct privilege checks confirm anon has no CRM table access; authenticated assignment/event writes are denied except through the guarded RPC, while allowed opportunity/after-sales update columns are narrowly scoped. The two company Proforma settings rows were initialized for the existing legal entities; the other new Proforma/CRM tables are empty. No customer, opportunity, activity, Proforma, bank-account or other transactional records were imported or altered by these schema additions. The source-level and disposable PostgreSQL checks passed for the current Proforma/CRM candidate revisions. The existing security advisor still reports the leaked-password-protection warning and an intentional authenticated-only SECURITY DEFINER CRM RPC warning; performance advisor reports unindexed foreign keys on the new additive tables. Production mode, module allowlists, and production deployment remain disabled.

The full app preview is not yet a shared live-data ERP: staging uses clearly labeled sample data and browser-local review storage. The next migration work is to connect the V6.7 UI data paths to the live company-scoped contracts and continue the remaining module foundations.


## Supply & Logistics migration update — 2026-10-31

A forward-only migration was added to GitHub and applied to the live BOKAN ERP Supabase project:

- Migration: `20261031082508_add_company_scoped_supply_logistics_foundation`
- New tables: `supply_shipments` and `delivery_orders`
- Both tables have RLS enabled, company-membership read policies, role-scoped insert/update policies, creator identity checks, company-scoped unique document numbers, quantity/status constraints, updated-at triggers, and supporting indexes.
- Anonymous table privileges are revoked. Authenticated update privileges are restricted to operational columns.
- The existing V6.7 Supply & Logistics Control Tower now uses the active authenticated company UUID to persist inbound shipment plans and delivery controls. It rejects a UI-selected company that differs from the authenticated active company and does not fall back to sample/local data when live reads fail.
- The V6.7 entry and preserved review source are synchronized. The staging config, production mode, and reviewed production-tab allowlist remain disabled.

Scope limitation: this is the first persistence slice only. Sales-demand integration, warehouse reservations, goods receipt/stock posting, shipment containers, supplier/purchase-order linkage and logistics exception workflows are not yet live. The preview remains demo-only and must not be used for real transactions. Disposable PostgreSQL RLS tests and static UI-contract tests have been added to GitHub Actions; results must pass before this slice is considered browser-verified.
