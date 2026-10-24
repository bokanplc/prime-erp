# BOKAN ERP V6.7 — Production Module Readiness Matrix

**Updated:** 2026-10-24  
**Current release decision:** no business module is approved for hosted production.

This matrix separates source code presence from real backend readiness. A screen or a local-preview workflow is not a completed production module.

| Module group | Current source path | Database / trusted operations | Required production proof | Current status |
|---|---|---|---|---|
| Authentication and profile | Supabase Auth bridge; `profiles` | Profile schema and RLS exist only in the first-slice SQL draft; real project has no app tables | Real Supabase Auth sign-in/out, inactive/terminated user denial, profile provisioning, session lifecycle, direct Data API checks | Blocked |
| Company issuer details | `companies` and issuer settings bridge | First-slice SQL draft includes company rows and restricted TIN/address/phone updates | Real Supabase policy test for PRIME and BlackRock; issuer edits audited and scoped | Blocked |
| Bank accounts | `company_bank_accounts` snapshot read | Production replacement is disabled; draft has read-only access | Real bank rows, scoped reads, atomic audited maintenance workflow, snapshot/version tests | Blocked |
| Proformas | Supabase proforma bridge + `bokan_save_proforma` draft | Disposable PostgreSQL CI tests cover draft RLS/grants, server-side totals, numbering, revisions and some role checks | Apply only after review; real Supabase Auth/JWT and Data API/RLS tests; browser create/reload/revision tests; confirm Ethiopian VAT discount treatment with accountant | Partially tested in disposable PostgreSQL; not production-ready |
| Sales Proforma requests | `prime_proforma_requests` localStorage | No canonical request table or tested server workflow | Company-scoped request persistence, approval/status transitions, audit, reload/cross-device test | Blocked |
| CRM customers and activity | `bokan_customers`, activity/assignment bridge; legacy localStorage stores | Tables absent; assignment history + customer update is currently multi-step | Canonical customer model, company and salesperson FKs, atomic reassignment, role policies, XSS and cross-tenant tests | Blocked |
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
