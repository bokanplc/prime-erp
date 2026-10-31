# BOKAN ERP V6.7 — BlackRock-only migration baseline

**Target:** BlackRock Investment PLC only  
**Working branch:** `feature/blackrock-only-v67` (branched from `deploy/secure-staging`)  
**Production release:** Not authorized until full module and security verification passes.

## Verified starting point

- Full application source: `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`
- Source size at audit: 827,762 characters; 9,432 lines.
- Source blob SHA at audit: `9771fb617ae238ac8fc94d5c629453b687d178e4`.
- Supabase project: `kafiwnuynjemufnankvi` (`BOKAN ERP`), ACTIVE_HEALTHY, PostgreSQL 17.
- Applied Supabase migrations: 29.
- Public tables: 27; RLS enabled on all 27.
- Companies currently in database: BLACKROCK and PRIME, both active.
- Prime-owned rows found: 23 customers, 3 products, 25 sales documents, 28 sales-document items, 10 purchase documents, 10 purchase-document items, 1 company membership, and 1 company proforma-settings row. No Prime rows were found in the other company-scoped tables checked.
- BlackRock-owned rows found: 22 customers, 3 products, 25 sales documents, 28 sales-document items, 15 purchase documents, 15 purchase-document items, 1 company membership, and 1 company proforma-settings row.
- Company foreign keys include both CASCADE and RESTRICT actions. The Prime company record must not be deleted until dependent rows and restrictive relationships have been checked and the application no longer relies on Prime.
- Vercel project `prime-erp` latest observed deployment is ERROR, not production-ready. The failed build at commit `50f0174` reported: `Staging entry point must match reviewed source before sanitization.`
- At that failed commit, the staging entry differed from the reviewed source by 29 characters in the CRM membership role filter. Current branch files were subsequently observed with matching source/entry blob SHAs; a fresh preview build still needs verification.
- The V6.7 source contains explicit multi-company UI and Prime defaults. These must be removed or rewritten for a single-company BlackRock operating model.
- Static source scan found 44 distinct Supabase table references. Only 15 are present in the current public schema; 29 referenced tables are absent. Missing references include HR/payroll and finance entities (for example `bokan_employees`, `bokan_payroll_runs`, `bokan_journal_entries`, `bokan_ar_invoices`, and others). Existing canonical finance tables include `ledger_accounts`, `fiscal_periods`, `journal_entries`, and `journal_lines`; the V6.7 finance bridge must be aligned with the actual schema or the missing schema must be deliberately migrated.
- Supabase security advisors currently report three authenticated-callable SECURITY DEFINER functions and leaked-password protection disabled. These require review before production release.

## BlackRock-only completion requirements

1. Keep the full V6.7 application and its functional modules; do not replace it with a starter/demo menu.
2. Remove Prime company configuration, company switching, Prime-specific business data, seed records, UI text, and authorization paths.
3. Preserve the BlackRock company record, membership, and BlackRock-owned records.
4. Retain company scoping and RLS as security controls even though only one company remains.
5. Reconcile every application database/RPC reference against the deployed Supabase schema and migrations.
6. Implement and test all required persistence workflows, especially finance posting/reversal, AR/AP, inventory, CRM, HR, payroll, procurement, and logistics.
7. Keep staging and production configuration fail-closed. Never expose service-role/secret keys in browser code.
8. Verify authentication, role permissions, RLS, CRUD workflows, posting controls, reports, and browser smoke tests.
9. Promote only a tested production deployment. Do not change `main` or production domains before release acceptance.

## Safety notes

- Do not delete the GitHub repository or the full application source.
- Do not delete the BlackRock company, its records, or its membership.
- Do not delete the Supabase Auth user merely because a Prime membership is removed; the same login may be the BlackRock administrator.
- Prime data removal is authorized by the project owner, but must be performed as a controlled, dependency-aware database change and verified afterward.


## Work completed on 2026-10-31

- Created working branch `feature/blackrock-only-v67` from `deploy/secure-staging`; `main` and production were not changed.
- Reworked the full V6.7 source and staging entry as a BlackRock-only application. The source and entry files now have matching Git blob SHAs; the application retains its full V6.7 module body and is approximately 823 KB / 9,396 lines.
- Removed Prime company names, Prime identifiers, company-selection UI, group/company-context pages, and Prime demo membership from the application source and build sanitizer. Production profile resolution now accepts only active BLACKROCK memberships.
- Applied Supabase migration `20261031132355_decommission_prime_company_and_data`.
- Verified that the only remaining company row is active `BLACKROCK — BlackRock Investment PLC`, with one active membership, 22 customers, 3 products, 25 sales documents, and 15 purchase documents.
- Verified zero residual Prime-linked rows across all 26 company-scoped tables checked, including company memberships, customers, products, sales and purchase documents/items, CRM, logistics, finance, and company settings.
- The Prime membership was removed by the company cascade. The Supabase Auth user was deliberately not deleted because the login may also be the BlackRock administrator.
- Added the applied SQL migration to this branch at `supabase/migrations/20261031132355_decommission_prime_company_and_data.sql`.
- No production deployment was promoted and `main` remains untouched.
- An earlier Vercel build attempt hit the Hobby/build limit; that was superseded by a successful READY preview build on the same working branch. No paid upgrade was made.

## Remaining production blockers

- The source scan still identifies 29 Supabase table references absent from the current 27-table public schema. These must be reconciled module by module; finance should use the existing canonical ledger/sales/purchasing tables where appropriate, and HR/payroll plus other missing operational entities need reviewed schema and RLS.
- The V6.7 production configuration remains deliberately disabled. No service-role key is present in browser code.
- The Supabase security advisor still reports three authenticated-callable SECURITY DEFINER functions for review and leaked-password protection disabled.
- Full browser/functional tests and a production build remain outstanding. Do not promote until these are complete.


## Additional migration work completed on 2026-10-31

- Applied migration `20261031133249_add_blackrock_hr_payroll_persistence`: company-scoped employee, attendance, leave, performance, disciplinary, payroll-run, payroll-line and payroll-approval tables; compatibility views for the legacy HR screens; profile records; HR role support; and RLS policies.
- Applied migration `20261031134003_add_blackrock_sales_operations_persistence`: company-scoped customer billing, expenses, notifications, sales targets, trip plans, per-diem requests, visit reports, stock entries, stock ledger and document metadata; plus the CRM customer-log compatibility view and profile/assignment synchronization.
- Applied migration `20261031140120_sync_profile_role_on_membership_changes` so the profile role stays synchronized when a BlackRock membership role changes.
- Updated the V6.7 finance production bridge to use the existing canonical Supabase ledger, sales, purchasing, payment and fiscal-period tables, and to scope by the authenticated user's BlackRock company UUID rather than a company-code string.
- Updated HR attendance to read/write the company-scoped Supabase attendance table when production mode is enabled.
- Updated CRM follow-up and customer reassignment to use profile roles and the CRM assignment RPC; production CRM activity history is treated as an audit trail and cannot be deleted from the UI.
- Latest verified Supabase migration count: 34.
- Latest verified public base-table count: 46. All 42 literal `.from('table')` references in the full V6.7 source now resolve to an existing public table or one of the compatibility views. This is a schema-reference check, not proof that every UI workflow has passed end-to-end testing.
- Latest source and staging entry blob SHAs match. The full source is 830,670 characters / 9,520 lines and contains no remaining case-insensitive `Prime` identifier.
- Supabase now contains exactly one active company: BlackRock Investment PLC.

## Remaining work before production

- The V22 corporate finance modules still keep several module datasets in browser localStorage. They must be migrated to durable, company-scoped server persistence and connected to the canonical posting workflows before those tabs are production-enabled.
- Review and test all HR, payroll, sales, stock, billing, expenses, documents, notifications, trip and per-diem forms against their new tables and RLS policies.
- Review the three previously identified SECURITY DEFINER warnings and enable leaked-password protection.
- Latest Vercel preview deployment is READY for commit `d2697c14` on `feature/blackrock-only-v67`. Its build log confirms a sanitized release candidate, 20 fixture collections emptied, preview-admin fallback removed, and production mode deliberately disabled. No production release has been promoted.
- `BOKAN_REVIEWED_PRODUCTION_TABS` and `ENABLED_PRODUCTION_TABS` remain empty/disabled. `main` and production remain untouched. No production release has been promoted.


## Vercel preview verification

- Deployment: `dpl_FU8AX5vqZPJNEGB4QWhaA5Rzibg`
- Preview URL: `https://prime-ndvhjb38d-bokanplc-3642.vercel.app`
- Git branch/commit: `feature/blackrock-only-v67` / `d2697c14b4878f88f76c4f80539c2797ecfa6982`
- Vercel state: `READY`; target remains preview (not production).
- The deployed source and staging entry have matching Git blob SHAs and match the current full V6.7 source.
- Build output: `dist/release/index.html`; 20 known fixture collections emptied; preview-admin identity fallback removed; production mode remains disabled by design.
- Web-based external inspection could not access the preview URL, so the build is verified but the browser login and interactive workflows have not yet been end-to-end tested.
