# BOKAN ERP V6.7 static audit

Audit date: 2026-10-21  
Source inspected: `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`  
This report describes static review and targeted fixes only; it is not a production certification.

## Checks completed
- Extracted 36 non-empty inline JavaScript blocks and ran Node.js syntax validation: **0 syntax failures** after the targeted patches.
- Identified 41 distinct table names referenced by `.from(...)` calls (full list in `DATABASE_OPERATION_INVENTORY.md`).
- Found 96 `localStorage` references in the HTML source.
- Found mock-backend fallback logic (`makeMockSupabase()`).
- Found no literal `service_role` or `SUPABASE_SERVICE_ROLE_KEY` strings in the inspected HTML.
- Found explicit review-source comments indicating authentication was bypassed for the review build.
- Confirmed the Supabase project has zero public application tables and no recorded migrations.
- Fixed a confirmed production Proforma issuer runtime defect: an undefined `se` variable was referenced after the `companies` and `company_bank_accounts` queries. That reference is now removed; the actual query errors `ce` and `be` are still checked.
- Removed the legacy complementary-services mapping from the Proforma row adapter, consistent with the requested removal of that section.
- Added a hosted fail-closed guard: when served from a non-local host without explicit valid production Supabase configuration, the page blocks the mock/demo ERP interface and displays a setup warning.

## Local-storage keys requiring review

The source contains these literal keys. The names suggest that at least some may hold operational or customer data; every read/write must be traced before live use.

| Key | Required review |
|---|---|
| `customers` | Determine whether customer records are stored locally rather than in shared Supabase |
| `customer_logs` | Determine whether CRM activity/history is stored locally |
| `prime_customers` | Determine scope, migration, and company isolation |
| `prime_customer_logs` | Determine scope, migration, and company isolation |
| `prime_proforma_requests` | Determine whether requests need shared persistence and authorization |
| `bokan_sales_lifecycle_v1` | Sales lifecycle persistence and company scope |
| `prime_v27_ops` | Identify operational data and convert business records to shared persistence |
| `prime_v22_corporate` | Identify corporate/business data versus UI preferences |
| `prime_v40_transactions` | Determine whether transaction data is local-only |
| `prime_v28_control` | Determine whether control/audit records are local-only |
| `bokan_active_company_context` | UI context only if always validated against the authenticated profile |
| `prime_v53_lastscan` | Determine if this is a harmless scan timestamp or an operational control |
| `prime_release_environment` | Review release-mode switching; must not let users enable unsafe modes |
| `prime_release_role` | Never trust a local-storage role as an authorization boundary |
| `prime_release_last` | Determine whether this is UI metadata or an operational record |

## What these results mean
Passing JavaScript syntax checks confirms only that the extracted scripts parse. It does not prove that the page renders correctly, all features work, or the database schema/policies match the application.

The mock-backend fallback means production hosting must inject valid configuration and must not let staff mistake in-memory/demo data for saved ERP records. A role or company value in local storage is not a security boundary. The local-storage inventory above needs a module-by-module review so that customer, finance, HR, payroll, and audit data is centrally persisted and protected by database RLS.

## Deployment blockers
1. **Authentication:** the review source explicitly says auth was bypassed in review mode. Production must enforce Supabase Auth and active `profiles` before showing protected ERP screens.
2. **Database schema:** 41 direct table names are referenced; actual columns, foreign keys, write payloads, and legacy/new model duplication must be reconciled.
3. **Tenant isolation:** PRIME and BlackRock data must be isolated in RLS policies, not just in UI tabs or local storage.
4. **Local storage:** determine which keys contain business data and migrate those flows to shared, authorized persistence.
5. **Mock backend:** production must fail closed when configuration/session is absent, never silently show successful in-memory writes.
6. **Recovery:** establish and test manual export/recovery steps compatible with the current Free plan.
7. **Runtime:** browser smoke tests are still required for login, roles, company switching, proforma math, history, and key workflows.

## Current state
No application database schema changes have been made. The repository's `main` branch remains untouched. The staging branch contains the full reviewed source and audit documentation; it is not deployed.
