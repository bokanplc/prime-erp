# BOKAN ERP V6.7 — Browser Storage and Data Migration Inventory

**Status:** source-derived migration inventory; not a database schema or an instruction to import data.  
**Source reviewed:** `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` on `deploy/secure-staging`.  
**Purpose:** distinguish real business records from demo seeds, control settings, and UI state before replacing localStorage with durable, company-scoped persistence.

## Critical findings

1. The legacy adapter patches browser `localStorage.setItem/removeItem` and attempts to synchronize every localStorage key through `/api/store/:key`. The endpoint is not present in the repository. This generic key/value design must not be implemented without a strict key allowlist, schema validation, actor/company authorization, size limits, and audit.
2. The file contains localStorage modules that seed example accounting transactions and CRM/call-follow-up rows. A seed displayed in a browser is not proof of an actual business transaction. Do not bulk-import browser stores until each record set is classified and the owner confirms which records are real.
3. `prime_release_role`, `prime_release_environment`, and `bokan_active_company_context` are UI/control context. They must never grant role or company permissions.
4. Several records are duplicated or overlapping between old and new models, including `customers` / `prime_customers`, `customer_logs` / `prime_customer_logs`, and the newer `bokan_*` CRM tables. Importing all stores independently risks duplicates and inconsistent history.
5. The inventory below uses static source references. Dynamic helper calls and keys constructed at runtime mean this list is not a proof of every key; the migration must include runtime capture in a non-production browser before the final allowlist is approved.

## A. Explicit browser keys found in direct localStorage calls

| Key | Likely purpose from source | Data class | Recommended treatment |
|---|---|---|---|
| `bokan_active_company_context` | Selected company/group context | UI preference, security-sensitive input | Keep as UI preference only; derive access from server membership |
| `bokan_sales_lifecycle_v1` | Sales opportunities/orders lifecycle | Business records | Map to canonical CRM/opportunity/order tables after field review |
| `customer_logs` | Legacy CRM/customer activity | Business records; may contain personal contact details | Reconcile with CRM activity model; migrate only verified real records |
| `customers` | Legacy customer master | Business records | Reconcile with canonical customer table; deduplicate |
| `prime_customer_logs` | Legacy PRIME CRM activity | Business records | Reconcile with `customer_logs` and `bokan_customer_activities` |
| `prime_customers` | Legacy PRIME customer master | Business records | Reconcile with `customers` and `bokan_customers` |
| `prime_proforma_requests` | Proforma requests | Commercial records / customer data | Migrate to an explicit request workflow if still used; do not confuse with issued proformas |
| `prime_release_environment` | Release/readiness display context | Local control value | Never use as production environment authority |
| `prime_release_last` | Last local readiness scan timestamp | Local operational metadata | Optional, low-risk metadata; not proof of a server-side release check |
| `prime_release_role` | Release dashboard's displayed role | UI-only value; privilege-sensitive | Remove as authorization source; role must come from protected profile/membership |
| `prime_v22_corporate` | Corporate / accounting state, including ledger-like arrays | Financially sensitive | Split into canonical normalized finance tables; do not trust client-calculated totals or status |
| `prime_v27_ops` | Operations, procurement, stock, actions | Operational / inventory records | Map to approved procurement/inventory schema with company scope and transaction history |
| `prime_v28_control` | Approvals, reconciliation, cash/control state | Sensitive approvals/financial controls | Rebuild as normalized workflows with actor, timestamps, state transitions and audit |
| `prime_v40_transactions` | Integrated accounting/AR/AP transaction view | Financially sensitive | Reconcile with journal, invoice, receipt, bill, payment models; seed examples require explicit exclusion |
| `prime_v53_lastscan` | Last local data-quality scan timestamp | Operational metadata | Optional metadata; server-side audit should be authoritative |

## B. Additional module/key families observed

These names occur through module constants, generic storage helpers, or integration code, so they may not all appear in the direct-call list above.

| Family / examples | Likely content | Required decision |
|---|---|---|
| `prime_v23`–`prime_v26` and `prime_v29`–`prime_v35` | Accounting, sales/HR, control, reconciliation and posting modules | Inventory each actual key and distinguish derived dashboards from source-of-truth records |
| `prime_v41_approvals`, `prime_v45_stock`, `prime_v51_exceptions`, `prime_v52_period_control` | Approvals, stock, exceptions, fiscal-period state | Define canonical tables and allowed state transitions; no client-only approvals/posting |
| `bokan_customer_call_log_v2`, `bokan_sales_crm_v1` | Sales follow-up and call tracking | Decide whether the seeded call list is demonstration data or current operational data; deduplicate against CRM |
| `prime_suppliers`, `prime_products` and related stores | Supplier/product master data | Reconcile with finance, procurement and inventory models |
| `prime_prod_token` in sessionStorage | Legacy adapter session token | Keep short-lived/revocable and server-issued if a legacy API is retained; never treat a browser-stored role as trusted |

## C. Data classification and migration rules

### 1. Never import as real transactions without verification
- Any source array initialized with hard-coded seed rows.
- Records marked `Posted`, `Approved`, or similar only in localStorage.
- Demo profiles/users and sample balances.
- Release readiness values or client-side scan timestamps.

### 2. Candidate durable business data
- Customers, suppliers, products, opportunities, sales activities and follow-ups.
- Proforma requests and issued proforma snapshots.
- Employee/attendance/leave/performance records.
- Journals, invoices, receipts, bills, payments, stock entries, approvals and fiscal-period controls.

These candidates still require record-by-record field mapping, source-of-truth selection, tenant assignment, deduplication and owner confirmation before import.

### 3. Keep out of authorization decisions
- Active company selector/localStorage context.
- Local release role/environment.
- Any browser-only `role`, `company_code`, `created_by`, `approved_by`, `posted` or `active` value.
- Any local UI setting used to hide/show buttons.

## D. Safe migration sequence

1. **Inventory in a test browser:** log each storage key read/write, module owner, payload shape, size, and whether the module initializes demo seed data. Do not capture production secrets or upload personal data into logs.
2. **Classify sources:** tag each store as confirmed business, demo/seed, derived cache, preference, or unknown. Unknown data is not imported.
3. **Choose canonical models:** one company master; approved company membership/role model; canonical customer/CRM; one proforma versioning model; normalized finance/HR/inventory tables.
4. **Build a dry-run exporter:** export only allowlisted keys; include row counts and checksums; redact personal fields from diagnostics. Never silently overwrite source browser data.
5. **Normalize and validate:** assign explicit PRIME/BlackRock company IDs from verified records, deduplicate by approved business keys, validate references and totals, and quarantine conflicts.
6. **Import to a non-production schema/project first:** use idempotent batches and a migration ledger. No production import while table policies are untested.
7. **Reconcile:** compare counts and financial totals by company and period, sample source documents, verify proforma numbering/version history, and obtain owner sign-off.
8. **Cut over per module:** after read/write and direct-API authorization tests pass, change that module to database-backed reads/writes. Do not dual-write indefinitely.
9. **Retire generic sync:** remove the `Storage.prototype` interception and localStorage business-record path when all relevant modules have migrated. Keep only non-sensitive UI preferences locally.

## E. Minimum runtime test matrix

- Start with empty storage and confirm no demo record is misrepresented as persisted business data.
- Seeded/demo browser data is excluded from the migration export by default.
- PRIME user cannot read/write BlackRock records, and vice versa, even if localStorage is modified.
- A manipulated `prime_release_role=Administrator` or `bokan_active_company_context=GROUP` grants no privilege.
- A failed save produces a visible failure and does not report success or lose the prior committed value.
- Retry of an import/write does not duplicate a customer, proforma version, invoice, receipt, payment or stock movement.
- Imported financial totals and source/version links reconcile exactly.
- Browser storage is not the only copy of any business-critical record after cutover.

## Release gate

This inventory is for safe planning only. No data should be imported and no production mode enabled until the canonical schema, company membership model, table grants/RLS, private document storage, and test identities are implemented and tested.
