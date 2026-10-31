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
