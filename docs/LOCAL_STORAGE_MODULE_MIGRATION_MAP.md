# BOKAN ERP V6.7 — Browser Storage and Module Readiness Inventory

**Status:** source-derived migration inventory, updated 2026-10-24. It is not a claim that local records have been migrated or that any module is production-ready.

## Why this matters

A browser `localStorage` record is local to one browser profile and device. It is not shared company data, does not provide database transaction guarantees, is not protected by Supabase RLS, and can be edited by the person using the browser. Clearing embedded example seeds for a release does not convert these records into persistent server data.

The release gate now requires all of the following before the hosted Supabase client can initialize:
- `PRODUCTION_MODE: true`;
- `FULL_ERP_DATA_READY: true`;
- a non-empty valid Supabase configuration; and
- at least one tab explicitly listed in `ENABLED_PRODUCTION_TABS` **and** in the source-controlled `BOKAN_REVIEWED_PRODUCTION_TABS` allowlist.

Both tab lists are empty in the current staging configuration/source. Therefore, no module is approved for production, even if someone accidentally toggles only the two older boolean flags. This is an additional release guard, not a substitute for database authorization.

## Source-derived storage map

| Storage key(s) | Source module / apparent purpose | Data class | Required disposition before production |
|---|---|---|---|
| `bokan_active_company_context` | Company-context selector / current UI company | UI context, security-sensitive if misused | Keep only as a UI hint. Always derive authorization from authenticated profile/membership and RLS; never trust this key. |
| `bokan_proforma_company_settings_v2` | Proforma issuer/company settings fallback | Issuer identity and bank-detail cache | Production must read issuer settings from protected company tables. No local fallback for production writes. |
| `bokan_saved_proformas_v2` | Legacy local Proforma list/version history | Commercial and customer data | Production must use `proformas` and the trusted save RPC. Local history is preview-only; define any one-time migration/export before removing it. |
| `prime_proforma_requests` | Sales requests for a Proforma | Customer and sales workflow | Move to a company-scoped request table with actor/status audit, or keep hidden until that workflow is implemented. |
| `customers`, `customer_logs`, `prime_customers`, `prime_customer_logs` | Older CRM customer/activity stores and compatibility fallbacks | Customer/contact and sales activity | Reconcile with `bokan_customers` / activity tables; do not automatically merge differently shaped keys. |
| `bokan_customer_call_log_v2` | Sales call-log examples and edits | Customer contacts, phone numbers, salesperson assignments | Migrate to canonical CRM activity/assignment tables and company-scoped policies. Release seed is emptied; module remains unapproved. |
| `bokan_sales_hub_v1`, `bokan_sales_crm_v1`, `bokan_sales_lifecycle_v1` | Sales hub, follow-up integration, opportunities/orders | CRM pipeline and sales transactions | Map each record shape and source-of-truth relationship to canonical CRM/opportunity/order tables; never treat browser copies as authoritative. |
| `prime_v22_corporate` | GL, AR/AP summaries, bank/cash reconciliation and financial statements | Financial records | Replace with relational ledger/subledger data, validated posting workflows and company-scoped reads. |
| `prime_v23_controls`, `prime_v28_control`, `prime_v29_control` | Accounting/approval controls, reconciliation and close-control state | Financial approvals and close evidence | Move to structured control/approval/event tables with actor, timestamps, authorization, and immutable audit history. |
| `prime_v24_attendance`, `prime_v25_v26` | Attendance, sales/HR dashboards and related records | Employee/HR data | Reconcile with `bokan_attendance_records` and canonical employee records. Do not expose HR self-service until row/manager scopes are tested. |
| `prime_v27_ops` | Procurement, inventory/stock and operations actions | Inventory and procurement | Replace with canonical purchase/warehouse/stock-movement tables and atomic movement workflows. |
| `prime_v40_transactions` | AR/AP, sales and finance transaction register | Financial transactions | Replace with canonical finance tables and trusted posting/allocation operations; posted records need reversal, not ordinary edits/deletes. |
| `prime_v41_approvals`, `prime_v41_audit` | Governance approvals and audit events | Approval/audit data | Server-side append-only audit and approval workflows; browser-generated actor names are not proof of identity. |
| `prime_v45_master`, `prime_v45_stock`, `prime_v45_pay` | Enterprise master data, inventory and payroll examples | Customer/supplier, stock, payroll-sensitive | Move to canonical relational tables with distinct finance/HR policies. Payroll must never be stored as trusted local state. |
| `prime_v50_reconciliation`, `prime_v50_close` | Reconciliation and integrated close controls | Finance and audit evidence | Server-side controls tied to real ledger/period records; no browser-only close or reconciliation state. |
| `prime_v51_exceptions` | Exception workbench | Operational/finance exceptions | Persist with company, owner, status-transition and audit rules; keep unavailable until implemented. |
| `prime_v52_period_control`, `prime_v52_period_events` | Period locks and lock events | Financial close controls | Enforce period locking in database workflows. Browser lock flags must not authorize or prevent ledger posting. |
| `prime_v53_quality_issues` | Master-data quality findings | Quality findings | Store findings server-side if shared/audited; do not treat browser-local findings as a server audit. |
| `prime_v30_controls`, `prime_v32_trace`, `prime_v33_reconciliation`, `prime_v34_close_control`, `prime_v35_postings` | Embedded operational controls, transaction trace, reconciliation, close and posting examples | Finance/control sample data | Release builder empties these embedded examples. Their live workflows still require real backend implementation and authorization. |
| `bokan_access_registry_v2`, `bokan_access_audit_v2` | Local access-governance registry and audit examples | Identity/access control | Must not create or grant real user roles from localStorage. Replace with controlled Supabase Auth provisioning and trusted audit records. |
| `bokan_supply_tower_v1` | Supply/logistics inbound and delivery state | Procurement/logistics | Replace with canonical supply/logistics tables, tenant scope, FK validation and atomic stock/order workflows. |
| `prime_release_control`, `prime_release_audit` | Local release readiness checklist and audit entries | Release-review metadata | May remain a local checklist only if labelled as such; never use it as a real security audit or deployment approval. |
| `prime_release_environment`, `prime_release_role`, `prime_release_last` | Selected environment/role label and last local scan time in the release-readiness panel | UI/checklist metadata | These values are user-editable and must never establish actual environment, identity, role, or readiness. |
| `prime_v53_lastscan` | Last local quality scan timestamp | UI metadata | Local display only; use server-side scan/run records if auditability is required. |

## Release-seed hygiene versus persistence

The release builder deliberately empties known demo/fixture arrays in source modules and replaces the mock Supabase client with a deny-only stub. That prevents known embedded examples from shipping as real company data. It does **not**:
- migrate existing localStorage records to PostgreSQL;
- make a browser-local record visible to another employee/device;
- provide authorization, concurrent updates, audit trails, backups or recovery;
- make a module production-ready merely because its demo seed is empty.

The reviewed source retains local-preview examples for development. The generated release candidate is a separate sanitized artifact and must be rebuilt and retested after source changes.

## Module activation rule

Do not add a tab to either production allowlist until all relevant gates are complete:
1. canonical table and complete payload/join mapping;
2. schema, grants, RLS and tenant isolation;
3. trusted write boundaries for multi-step/financial operations;
4. anonymous, cross-company, wrong-role and invalid-payload denial tests;
5. real Supabase Auth/Data API integration and browser persistence test;
6. migration/export decision for any genuine pre-existing local records;
7. release candidate regenerated and all CI checks passing.

The current reviewed-tab allowlist is intentionally empty. This is not a statement that the ERP has no usable local-preview functionality; it means no hosted business module has yet passed the complete production acceptance gate.
