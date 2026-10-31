# BOKAN ERP V6.7 — Production Module Readiness Matrix

**Updated:** 2026-10-27  
**Current release decision:** no business module is approved for hosted production.

This matrix separates source code presence from real backend readiness. A screen or a local-preview workflow is not a completed production module.

| Module group | Current source path | Database / trusted operations | Required production proof | Current status |
|---|---|---|---|---|
| Authentication and profile | Supabase Auth bridge; live `company_memberships` + `companies` | The bridge now reads active live memberships and maps only supported roles; trusted user provisioning is still missing | Real Supabase Auth sign-in/out, multi-company switching, unsupported-role denial, provisioning, session lifecycle, direct Data API checks | Partially wired; not production-ready |
| Company issuer details | Live `companies.id/code/name/is_active` plus candidate `company_proforma_settings` | Candidate adds company-ID settings and an authorized RPC; it is not applied to live | Real Supabase policy test for PRIME and BlackRock; owner-verified issuer details; audit and browser tests | Blocked; candidate under test |
| Bank accounts | `company_bank_accounts` snapshot read | UUID-company candidate grants scoped reads; production edits fail closed | Owner-verified bank rows, real RLS tests, atomic audited maintenance workflow, snapshot/version tests | Blocked; candidate under test |
| Proformas | Supabase proforma bridge + UUID-company candidate `bokan_save_proforma` | Added separate PostgreSQL 17 job for active/inactive membership, unauthenticated writes, cross-company isolation, issuer settings, totals, revisions, grants and concurrent numbering; latest run not verified | Confirm CI success; real Supabase Auth/JWT/Data API/RLS tests; browser create/reload/revision tests; confirm Ethiopian VAT discount treatment with accountant | Candidate only; not production-ready |
| Sales Proforma requests | `prime_proforma_requests` localStorage | No canonical request table or tested server workflow | Company-scoped request persistence, approval/status transitions, audit, reload/cross-device test | Blocked |
| CRM customers and activity | Existing live `public.customers` master plus live `crm_*` tables | Live schema now includes company-scoped assignments, append-only assignment events, activities, opportunities and after-sales tasks; guarded manager-only reassignment RPC; disposable PostgreSQL tests passed | Wire the existing V6.7 CRM screens/bridge to these table contracts; real Supabase JWT/Data API, persistence/reload, customer duplicate and role/cross-tenant tests | Backend foundation applied; UI integration pending |
| Sales pipeline and follow-ups | `bokan_sales_hub_v1`, `bokan_sales_crm_v1`, lifecycle localStorage | No canonical persistence proven | Opportunity/order/activity schema, assignment rules, server-side validation, role-scoped tests | Blocked |
| Procurement and logistics | Newer generic `bokan_*` CRUD bridge and local `bokan_supply_tower_v1` | Referenced tables absent; generic CRUD lacks a complete per-table contract | PO/receipt/shipment/delivery lifecycle, FK/tenant checks, atomic stock movement and reversal tests | Blocked |
| Inventory and stock | `prime_v27_ops`, `prime_v45_stock`, local stock/ledger modules | Browser-local records; no trusted movement/balance workflow proven | Canonical inventory schema, stock reservation/movement transactions, duplicate/idempotency and negative-stock tests | Blocked |
| General ledger, AR/AP and cash | `prime_v22_corporate`, `prime_v40_transactions`, `prime_v50_*` and related local modules | Browser-local records; only proforma slice has a schema draft | Chart/account validation, balanced postings, period controls, invoice/payment allocation, immutable posting and reversal tests | Blocked |
| HR, attendance, leave, performance, discipline | Legacy/newer employee/leave/review models; local attendance key | Duplicate models; no real tables | Canonical HR model, employee self/manager scopes, termination handling, sensitive-data denial tests | Blocked |
| Payroll and approvals | Local payroll examples plus newer `bokan_payroll_*` bridge references | Tables absent; highly sensitive | Payroll calculations, preparer/approver separation, company/period scope, immutable approvals and direct API denial tests | Blocked |
| Documents / repository | `documents` metadata + Storage helper | Private bucket and signed-download flow not implemented; production upload/download disabled | Private Storage policy, same-company/category access, signed URL expiry, retry-safe metadata/object lifecycle | Blocked |
| Access registry / role administration | `bokan_access_registry_v2` local UI and profile-role handler | Local registry is not real provisioning; role changes are only UI-guarded | Trusted user provisioning, no self-role escalation, audit, cross-company authorization tests | Blocked |
| Quality, period close, reconciliation, exception and release-control panels | `prime_v30_*`, `prime_v50_*`, `prime_v51_*`, `prime_v52_*`, `prime_v53_*`, local release-control keys | Mostly browser-local state | Convert business-critical controls to server-side records and trusted transitions; label local readiness panels as advisory only | Blocked |

## Release allowlist behavior

The source has a source-controlled `BOKAN_REVIEWED_PRODUCTION_TABS` list and the staging config has `ENABLED_PRODUCTION_TABS`. Both are intentionally empty. Production startup now requires at least one configured tab to also be source-reviewed, and navigation is the intersection of:
1. the authenticated role's permitted tabs; and
2. the explicitly enabled and source-reviewed module tabs.

This prevents setting `PRODUCTION_MODE` and `FULL_ERP_DATA_READY` alone from automatically exposing every legacy module. Database RLS and grants remain the actual security boundary; a navigation allowlist is only an additional release safeguard.

## Definition of “ready”

A module can be added to the source-reviewed allowlist only after its schema/payload contract, grants/RLS, trusted write boundaries, real Supabase integration tests, persistence/reload test, cross-company denial tests, and sanitized release-candidate tests pass. Emptying sample data is necessary hygiene, not production readiness.


## Live membership integration update — 2026-10-26
- The full V6.7 Supabase login bridge now reads the actual `company_memberships` relation and joined active company row instead of querying a nonexistent `profiles` table.
- Role mapping is conservative: owner/admin → admin, manager → management, sales → sales, accountant → accounting, staff → data_entry. Unsupported roles such as viewer/inventory are not elevated into an unrelated full-ERP role and are denied by this bridge.
- Company switching is limited to active memberships returned by Supabase. The localStorage company context is only a selection hint; it cannot create authorization.
- Production role changes are now blocked until a trusted Auth user provisioning and membership-management workflow is implemented. The old preview role editor remains preview-only.
- This source change is not a live database change. The production module allowlists and production configuration remain disabled/blank, and all modules still require real Auth/JWT/browser and data-persistence testing.


## CRM security follow-up — 2026-10-30

The company-scoped CRM candidate was hardened without changing the live database. Direct reassignment-table UPDATE is removed; ownership transfers must use the atomic manager-only RPC that writes the assignment and immutable event together. Opportunity and after-sales ownership checks now require active same-company memberships, and UPDATE privileges are column-scoped to prevent rewriting tenant/customer/creator identity. Additional disposable PostgreSQL denial tests were added to the existing CI workflow. See `docs/CRM_SECURITY_HARDENING_2026-10-30.md`.

This does not change the CRM release decision: the backend schema is applied, but the existing V6.7 bridge still references legacy `bokan_*` names; no CRM UI tab is enabled for production, and actual Supabase JWT/Data API and browser persistence tests remain outstanding.


## Live backend migration update — 2026-10-31

- Applied the UUID-company Proforma foundation to live Supabase as migration `20261031080833_add_company_scoped_proforma_foundation`.
- Applied the company-scoped CRM foundation as migration `20261031081151_add_company_scoped_crm_foundation`.
- The 9 new Proforma/CRM tables have RLS enabled. Anonymous CRM table grants are revoked; authenticated users can read assignment/history rows but only the guarded manager-only RPC can write them.
- The full V6.7 review interface is deployed to Vercel from `deploy/secure-staging` in sample-data-only mode. Production mode and module allowlists remain disabled.
- CRM source bridge table names still need to be aligned with the live `customers` + `crm_*` contract; no production module is enabled yet.
