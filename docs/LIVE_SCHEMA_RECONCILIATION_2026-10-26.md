# BOKAN ERP V6.7 — Live Schema Reconciliation

Verified: 2026-10-26 using the connected GitHub, Supabase, and Vercel integrations.
Scope: read-only state inspection and source/release status reconciliation. No live schema, Auth, Storage, or deployment changes were made during this check.

## Current facts that supersede older status entries

The deployment-status file contains historical check-ins from October 21 and later. Several older sections state that the connected Supabase project has no application tables or migrations. That was the state observed at those earlier dates, but it is not the current state. Use this dated section for the latest inspected project state; retain older sections as historical context.

### Supabase project

- Project: QuickBooksApp
- Project reference: kafiwnuynjemufnankvi
- Region: eu-central-1
- Reported status: ACTIVE_HEALTHY
- Current migration-history endpoint reports 15 applied migration records.
- Current public table inspector reports 12 tables, with RLS enabled on all 12.
- The table inspector reports two company rows and two company-membership rows; it reports zero rows in the ten operational tables listed below.
- No Supabase Edge Functions or development branches were returned by the connected tools.

Current public tables:

| Table | RLS enabled | Reported rows |
|---|---:|---:|
| companies | Yes | 2 |
| company_memberships | Yes | 2 |
| customers | Yes | 0 |
| products | Yes | 0 |
| sales_documents | Yes | 0 |
| sales_document_items | Yes | 0 |
| suppliers | Yes | 0 |
| purchase_documents | Yes | 0 |
| purchase_document_items | Yes | 0 |
| stock_movements | Yes | 0 |
| sales_payments | Yes | 0 |
| supplier_payments | Yes | 0 |

### Applied migration versions and names currently returned

1. 20261025065910 — initial_multi_company_sales_foundation
2. 20261025072547 — revoke_unauthenticated_erp_table_access
3. 20261025124247 — add_missing_foreign_key_indexes
4. 20261025124312 — atomic_sales_document_creation
5. 20261025154749 — add_purchasing_inventory_and_sales_payments_foundation
6. 20261025155146 — index_new_erp_foreign_keys
7. 20261025155628 — add_inventory_stock_balance_view
8. 20261025160228 — atomic_purchase_document_creation
9. 20261025161004 — atomic_purchase_receiving_and_stock_posting
10. 20261026091615 — sales_stock_posting_and_supplier_payment_reconciliation
11. 20261026091657 — sales_document_approval_and_product_linking
12. 20261026091807 — include_supplier_payment_created_at_in_reconciliation_view
13. 20261026092227 — enforce_supplier_payment_balance_and_column_permissions
14. 20261026092354 — update_purchase_payment_status_for_partial_payments
15. 20261026094634 — index_supplier_payment_foreign_keys

The connected migration-list operation returned migration versions/names, not each migration's SQL body. The live migration SQL therefore still needs to be reconciled to source-controlled files before any further schema change.

## Material schema mismatch — do not apply the old first-slice migration

The staging branch contains one candidate migration at supabase/migrations/20261024000000_core_proforma_mvp.sql. It defines five tables: companies, profiles, company_bank_accounts, custom_terms, and proformas. CI executes that candidate against disposable PostgreSQL only; it has not been validated as an additive migration for the current live project.

The live project has a newer company/membership pattern: companies exposes an id/code/name/is_active-style contract and company_memberships links company_id and user_id with company-specific role and active status. The candidate instead defines its own companies shape and profiles with a company_code/role style. Those assumptions are not interchangeable. Applying the candidate as-is risks incompatible or overlapping tenant/identity models.

Do not apply, repair-in-place, or rerun the candidate against the connected project until the canonical company and membership model, proforma ownership/numbering design, live migration parity, role mapping, grants, RLS, and rollback/recovery path have been reviewed together.

## Full application coverage remains incomplete

The full staged V6.7 HTML source inventory records 41 literal direct-table names plus helper calls for 14 additional logical names (55 logical names total). Its first-slice draft defines five tables, so the static draft audit reports 50 table definitions still missing from that draft. That 5/50 count refers to source-draft coverage; it must not be misrepresented as a count of tables missing from the live project, because the live project already has the 12-table sales/procurement/inventory foundation listed above.

Even with those 12 live tables, the full ERP has not been proven complete. CRM activity and assignment history, sales opportunities, Proforma persistence, legacy customer logs/billing, HR, leave, performance, discipline, payroll, journals, AR/AP, documents, notifications, and related controls still need canonical model reconciliation and real integration/security tests. Some legacy and BOKAN-prefixed source models overlap and must not be created as parallel tables merely because the source references both names.

The application source also retains a legacy adapter contract for /api/auth/login, /api/auth/change-password, /api/auth/logout, /api/bootstrap, and /api/store/*. No matching functions/api/* source files are present on the current staging branch. The hosted adapter must remain fail-closed unless the affected modules are migrated to the Supabase-backed path or a separately reviewed authenticated backend is provided.

## Latest GitHub and deployment observations

- Private repository: bokanplc/prime-erp.
- Default branch main currently points to 1d835739b99b14e0765dcf1de6b6b001d15e4bdc (Add isolated demo-only ERP review mode). Its root index.html is now 50,370 bytes; older notes claiming it is one byte are stale. Do not overwrite main or copy the full staged HTML into it as a shortcut.
- Full V6.7 review source remains on deploy/secure-staging at staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html, with staging/index.html synchronized by the current CI checks.
- Draft PR #1 remains open and unmerged: https://github.com/bokanplc/prime-erp/pull/1.
- GitHub Actions run 40303637709 passed source guards and disposable PostgreSQL schema/RLS/grant/financial/concurrency tests: https://github.com/bokanplc/prime-erp/actions/runs/40303637709. This is not a real-browser test or proof that all modules are implemented.
- The latest Cloudflare preview build attached to PR #1, commit 1b434af, failed at 2026-10-26T09:58:06Z. Failure details are in the connected Cloudflare dashboard build record: https://dash.cloudflare.com/?to=/934af8c8f3ca6a51e2beac4e97afcb59/workers/services/view/prime-erp/production/builds/3cb2214f-7061-4479-9d3d-7c53a33510a9. The available GitHub comment exposes the dashboard link but not the detailed failure log, so the cause is not asserted here.
- A Vercel Hobby project named prime-erp also exists. Its latest READY deployment (dpl_4MJuxSdb63BmcjTxNL4nYtsjW3gr) points to main commit c715b70f228b75c42c1f21111d38bf034b74acfb, message 'Build usable sales workspace for customers products and sales drafts', not the current secure-staging SHA. The READY state of that deployment is not evidence that the full reviewed V6.7 staged source is deployed. The project environment-variable listing returned none; project protection settings should not be changed as part of this migration without a separate review.

## Security and release gates still open

- Supabase Security Advisor still reports Leaked Password Protection Disabled (auth_leaked_password_protection): https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection. No Auth setting was changed during this check.
- Performance Advisor reported 24 unused-index information findings. These are not grounds for deleting indexes without workload/query evidence.
- staging/config/config.js remains fail-closed: PRODUCTION_MODE=false, FULL_ERP_DATA_READY=false, ENABLED_PRODUCTION_TABS=[], Supabase URL blank, browser key blank. The source-reviewed tab allowlist is also empty.
- No module is approved for hosted production by the existing readiness matrix. Real Supabase Auth/JWT, direct Data API and cross-company denial tests, browser login/session/persistence/reload tests, private Storage and authorized signed downloads, canonical financial and HR workflows, and recovery/export rehearsal remain required.
- The documented Proforma 3% withholding rule above ETB 10,000 is enforced by the candidate SQL and tests, but the Ethiopian VAT/discount treatment and exact numbering convention still require the accounting/business review described in docs/OWNER_DECISIONS_BEFORE_PRODUCTION.md.

## Safe next steps

1. Preserve the live Supabase schema and migration history; do not apply the five-table Proforma candidate on top of the newer company/membership schema.
2. Reconcile all 15 live migration records with source-controlled migration SQL. Investigate whether source migration history is incomplete before deciding a source-of-truth strategy.
3. Compare main's root app and the Vercel deployment SHA against the staged V6.7 source so a smaller workspace is not mistaken for the complete application.
4. Build a canonical compatibility map for live companies/company_memberships versus draft profiles/companies, and for live sales_documents/sales_document_items versus legacy proformas, before designing additive migrations.
5. Continue source-only contracts and disposable test coverage for remaining modules; keep production mode and both module allowlists disabled.
6. Diagnose the Cloudflare preview failure through its available build log when access allows. Do not trigger a production deployment as a diagnostic.
7. No paid upgrade, production data write, migration application, PR merge, or deployment was performed for this reconciliation.

## Current release decision

STOP-SHIP. The 12-table live foundation is meaningful progress, but it is not a complete migration of BOKAN ERP V6.7. Keep production disabled and PR #1 in draft until the complete module, authorization, persistence, browser, build, and recovery gates pass.

## Follow-up: migration source recovery and grant review (2026-10-26)

- Copied the 11 applied migration SQL files available on `main` byte-for-byte into `deploy/secure-staging`. Four applied historical records still have no SQL source anywhere in repository history; their exact bodies were not fabricated.
- Moved the unapproved, conflicting Proforma schema out of `supabase/migrations/` into `supabase/candidates/core_proforma_mvp.sql`. Disposable PostgreSQL tests still exercise it, but standard migration tooling will no longer discover it as an executable migration.
- Added `docs/LIVE_MIGRATION_SOURCE_GAP.md` and `scripts/test-live-migration-source-parity.mjs` to document and test the 11/15 source-control state.
- Read-only privilege inspection found `authenticated` has `TRUNCATE`, `TRIGGER`, and `REFERENCES` on current public tables/views. Both existing views are `security_invoker=true`, and the private membership helper functions are restricted from `anon`/PUBLIC, but the non-DML grants are broader than a browser ERP needs.
- Added `supabase/candidates/revoke_non_dml_authenticated_privileges.sql`, a narrowly scoped candidate that preserves existing ordinary DML and column-level grants, plus a disposable PostgreSQL test and `docs/LIVE_GRANT_HARDENING_REVIEW.md`.
- Neither candidate has been applied to the connected Supabase project. The grant hardening is held for proper versioned migration/review because the four missing historical SQL bodies remain a source-of-truth gap.


## Follow-up: production Auth now matches live company membership

The staged Auth bridge was updated after this reconciliation to read `company_memberships` joined to `companies`, reject inactive memberships/companies, map only supported roles, and limit company switching to memberships returned by Supabase. The localStorage company key is only a preferred selection and cannot grant access. Production role edits remain disabled until trusted provisioning exists. This is source-only work; no live schema/Auth setting or deployment changed.
