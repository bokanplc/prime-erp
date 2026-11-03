# BlackRock-only V6.7 — browser storage inventory and migration gate

**Checkpoint:** 2026-11-02  
**Branch:** `feature/blackrock-only-v67`  
**Reviewed source:** `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`  
**Production state:** fail-closed; `PRODUCTION_MODE=false`, `FULL_ERP_DATA_READY=false`, empty production tab allowlist.

## Why this inventory exists

A source scan found 33 distinct browser-storage keys or declared storage constants in the full V6.7 HTML. Some are legitimate local presentation/context preferences; others contain business transactions, workflow state, approvals, finance, HR, logistics, quality and control records. A working screen that reads or writes these keys is not a migrated server-backed module.

This inventory is a source-level map, not a claim that local browser data has been imported. No local browser data has been read, copied, deleted or overwritten.

## Business-data stores requiring durable migration

| Browser key / family | Data domain indicated by source | Preferred durable destination / decision |
|---|---|---|
| `blackrock_customers`, `customers` | Customer master | Canonical `customers`; enforce BlackRock company scope and duplicate checks. |
| `blackrock_customer_logs`, `customer_logs`, `bokan_customer_call_log_v2` | Customer contact and call history | Canonical `customer_logs` and/or `crm_activities`; reconcile semantics before moving data. |
| `blackrock_proforma_requests`, `bokan_saved_proformas_v2` | Proforma requests and saved drafts | `proformas` plus the company-scoped request workflow; retain server-generated identity/version and approval history. |
| `bokan_proforma_company_settings_v2` | Issuer/company proforma settings | `company_proforma_settings`; use trusted RPC and role-limited writes. |
| `bokan_sales_crm_v1`, `bokan_sales_hub_v1`, `bokan_sales_lifecycle_v1` | Leads, opportunities, pipeline, activities and orders | `crm_opportunities`, `crm_activities`, `crm_customer_assignments`, `sales_documents`, `sales_document_items`, `sales_payments`; map every lifecycle transition before enabling. |
| `blackrock_v27_ops` | Procurement stages, stock, management actions | `purchase_documents`, `purchase_document_items`, `supply_shipments`, `stock_entries`, `stock_ledger`, `inventory_stock_balances`; management action queue needs an explicit durable model if not already represented. |
| `blackrock_v28_control` | Approvals, bank reconciliation and cash transactions | Existing domain-specific approval RPCs where available; `company_bank_accounts` is account master data only. Statement lines, matches and reconciliations require a dedicated model. Cash activity must use canonical receipts/payments, not a free-form ledger. |
| `blackrock_v29_control`, `blackrock_v30_controls` | Master-data and period-close control tasks | Use canonical master data; a durable close checklist/workflow model is required before these tasks can be treated as shared controlled records. |
| `blackrock_v32_trace`, `blackrock_v33_reconciliation`, `blackrock_v34_close_control`, `blackrock_v35_postings` | Traceability, reconciliation, close and posting support | Reconcile each screen with ledger, stock and payment source-of-truth records; do not duplicate posted financial or stock ledgers. Any missing workflow requires an additive company-scoped schema/RPC migration. |
| `blackrock_v40_transactions` | Seeded AR invoice, collection, AP bill and payment demo transactions | Remove the demo seed path from production. Replace reads/writes with `sales_documents`, `sales_payments`, `purchase_documents`, and `supplier_payments`; never import sample names or amounts as real business records. |
| `blackrock_v41_approvals` | Generic approval queue | Use each domain's authorized approval workflow. A generic browser-editable approval array is not an authorization system. |
| `blackrock_v45_pay` | Legacy payroll status/summary | Replace with `bokan_payroll_runs`, `bokan_payroll_lines`, and `bokan_payroll_approvals`; preserve HR confidentiality and approval/posting separation. |
| `blackrock_v51_exceptions`, `blackrock_v52_period_control` | Exceptions and accounting-period checks | Derive exceptions from source records and use `fiscal_periods` plus trusted close/posting rules. Do not let local state override period locks. |
| `blackrock_v53_quality_issues`, `blackrock_v53_lastscan` | Master-data quality findings and scan timestamp | Persist scan runs/findings only after defining actor, scope, severity, resolution and immutable history; current local scan is not authoritative. |
| `bokan_supply_tower_v1` | Inbound supply and delivery plan | `supply_shipments` and linked purchase/sales documents; keep shipment and stock posting as separate audited transitions. |
| `bokan_access_registry_v2` | Access/role registry | Supabase Auth plus `company_memberships` and audited trusted provisioning only; never trust browser roles. |
| `blackrock_v22_corporate` | GL, AR, AP, bank, procurement, inventory, fixed assets, budget, payroll, audit | Follow `BLACKROCK_V22_CORPORATE_PERSISTENCE_MIGRATION_MAP.md`; GL first, with ledger setup blocked pending approved chart of accounts and open fiscal period. |

## Local-only preferences and preview controls

The following keys appear to hold user-interface context, preview release settings, or timestamps rather than authoritative business transactions:

- `bokan_active_company_context` — selected company context only; authorization always comes from the authenticated membership.
- `blackrock_release_environment`, `blackrock_release_role`, `blackrock_release_last`, `blackrock_release_control` — local release-review controls; they must never be used as production authorization, audit, or readiness evidence.

These local preferences may remain client-side only if they are non-sensitive and cannot change server-side permissions or business state.

## Additional verified server-side foundations

The live Supabase schema contains company-scoped tables for CRM activities/opportunities, customer records/logs, proformas, supply shipments, purchasing, stock, employee/attendance/leave/performance, payroll runs/lines/approvals, expenses, trip plans, visit reports, sales targets, documents and general ledger. The 46 public base tables have RLS enabled. Object existence and RLS enablement alone do not prove the corresponding source screens use them correctly.

## 2026-11-02 Sales & CRM Command Center persistence checkpoint

The full V6.7 Sales & CRM Command Center now has a production-only Supabase adapter for these workflows:

- Loads BlackRock customers, CRM activities, opportunities, after-sales tasks and active sales/staff directory from company-scoped production APIs.
- Creates customer records through the canonical `customers` table. Initial owner assignment is attempted only for manager-authorized roles; ordinary sales users do not call the manager-only reassignment RPC.
- Creates opportunities through `crm_opportunities`.
- Creates activities through `crm_activities`, with actor/assignee identity supplied by the authenticated session.
- Creates after-sales tasks through `crm_after_sales_tasks`; the authenticated creator is assigned as owner so the existing owner-or-manager update policy permits completion.
- Completes after-sales tasks through the server API and reloads from Supabase.
- Keeps sales-order creation/status changes disabled in this Command Center until the screen is connected to the canonical sales-document/order workflow. It must not fall back to browser-only transaction records in production.

The staging entry is synchronized with the full V6.7 source. Regression tests enforce the production adapter, role-aware assignment, creator ownership, and fail-closed order behavior. GitHub Actions run 1069 passed all three job groups: source guards, Postgres schema smoke tests, and live BlackRock Proforma database smoke tests.

**Important limitation:** these are source-contract and database tests, not authenticated browser end-to-end tests. Employee accounts/memberships, live UI CRUD under each employee role, and the full sales-order workflow remain unverified. Existing browser-local data has not been imported or deleted.

## Release gate and next migration sequence

1. Keep every module that still reads or writes business records through browser storage outside the production allowlist.
2. Migrate canonical customer/CRM, proforma, supply, purchasing, stock, HR and payroll screens one workflow at a time; use server-returned IDs and state.
3. Replace demo seed transactions in V40 and local-only approvals/close/reconciliation state with real domain records or explicitly new company-scoped models.
4. Implement bank statement ingestion/reconciliation, fixed assets, budgets, management action queue, and close workflow only after schema/RLS/RPC design and tests.
5. Add authenticated browser tests for CRUD, approval, posting, reversal, company isolation and unauthorized role attempts.
6. Preserve local data until the owner can export, inspect, reconcile and approve any import. Never silently seed demo rows into BlackRock production.

**No production activation, PR merge, production deployment, or browser-local data cleanup is authorized by this inventory.**
