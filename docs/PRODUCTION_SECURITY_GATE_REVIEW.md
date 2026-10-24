# BOKAN ERP V6.7 — Production Security Gate Review

Reviewed: 2026-10-21  
Branch: `deploy/secure-staging`  
Source reviewed: `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`

## Decision

**Do not enable production mode or publish this ERP for business use yet.** The current artifact is a UI review build, not a production-ready application. The deployment config intentionally keeps production disabled.

## Verified blockers in source

1. **Review authentication bypass exists.** Source comments explicitly say the review build intentionally bypasses authentication. A demo/mock backend returns a hard-coded demo user and successful mock sign-in behavior.
2. **Mock backend remains available.** When production configuration is absent, the source can instantiate `makeMockSupabase()`. The hosted fail-closed guard is important, but must be verified end-to-end on the actual deployed build; no deployment should occur before that test.
3. **UI role filtering is not authorization.** `ROLE_TABS` and `__BOKAN_PROD_ALLOWED_TABS` control what the interface displays. They do not protect rows or actions. Supabase RLS and database constraints must independently enforce access.
4. **Profile trust needs database enforcement.** The client loads `profiles(id, full_name, role, department, company_code, active, terminated_at)` by the authenticated user ID. The database must prevent users from editing their own role, company assignment, active status, or termination status.
5. **Tenant separation is mandatory.** PRIME and BlackRock share the platform. Company-specific data needs an explicit legal-entity/company ownership field and policies that prevent cross-company access, including nested/related records.
6. **High-risk modules need tighter controls.** Payroll, employee records, disciplinary actions, expenses, bank accounts, invoices, journal entries, inventory ledgers, approvals, and audit records should not share one broad authenticated-user policy.
7. **Duplicate legacy/new models must be resolved first.** The UI calls both legacy tables (for example `customers`, `employees`, `leave_requests`, `performance_reviews`) and newer `bokan_*` tables. The canonical source of truth must be selected and the client calls reconciled before schema creation.

## Authentication and access requirements

- Use Supabase Auth for real users; do not create a shared demo/admin account.
- Provision each user's profile through a controlled administrator workflow. Do not let ordinary users insert or elevate their own profile.
- Keep role, company code, active status, and termination state authoritative in protected database records or trusted server-side claims; never trust editable user metadata for authorization.
- Add operation-specific RLS policies to every exposed table. Include both `USING` and `WITH CHECK` for updates, and enforce company scope in the database rather than relying on the UI's company selector.
- For HR/payroll, finance, bank details, approvals, and audit history, use least-privilege policies and immutable/append-only patterns where appropriate.
- Keep the browser configuration limited to the Supabase URL and publishable/legacy anon key. Never place a service-role or secret key in the HTML, repository, or browser.
- Ensure errors are visible and writes fail clearly; never fall back silently to mock data in a hosted environment.
- Verify unauthenticated requests are denied and test separate PRIME, BlackRock, HR, sales, accounting, and administrator access before production activation.

## Safe implementation sequence

1. Finish a field/payload inventory for all database operations, including joins, RPC calls, and localStorage-backed business data.
2. Resolve legacy/new table duplication and define one canonical model per business domain.
3. Draft and review schema + RLS policy SQL without applying it to the live project yet.
4. Test the schema and policies using a non-production/test environment if available on the existing free plan.
5. Run Supabase security advisors and test anonymous, cross-company, unauthorized role, and update-escalation scenarios.
6. Fix and test the hosted fail-closed guard and authentication flow.
7. Only then configure staging credentials and deploy a controlled staging build. Keep production mode disabled until smoke tests pass.

## Current state

- Supabase project has no application tables or migrations as of the latest read-only inspection.
- Staging config remains disabled with blank credentials.
- No production database schema has been created and no live deployment has been performed.
- This review is documentation only; it does not change the database or enable production.
