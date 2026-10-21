# BOKAN ERP — Secure Staging

This branch is a staging workspace. It is not a production deployment.

## Deployment guardrails
- The `main` branch is preserved.
- Keep the repository private.
- Do not place Supabase service-role/secret keys in browser code or Git.
- The application must fail closed in production if Supabase configuration is missing; mock/in-memory fallback is for preview only.
- Every exposed application table must have row-level security (RLS) and company-scoped authorization.
- Do not enable public access to employee, payroll, customer, accounting, or proforma data.
- Do not deploy until schema, authentication, authorization, and smoke tests pass.

## Current environment audit (2026-10-21)
- Supabase project: `kafiwnuynjemufnankvi` (Free plan; no upgrade assumed).
- `public` application tables: none detected.
- Recorded migrations: none detected.
- Automated backups/PITR: not assumed available on this plan; preserve migration SQL and export data regularly where feasible.
- The full reviewed V6.7 HTML source is now committed at `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`.
- The source and audit documents are on `deploy/secure-staging`; the root `index.html` and `main` remain unchanged.
- The app is not live yet; source upload is not a deployment.
- Vercel account inspection currently returns no accessible teams or projects, so no Vercel project is available to deploy to from the connected account. Vercel Hobby is also not an appropriate default for a commercial business ERP.
- The hosted HTML now fails closed to a setup message when production configuration is missing; this does not replace authentication, database RLS, or runtime testing.

## Next steps
1. Map the source's database operations to an exact field-level schema.
2. Prepare and review least-privilege SQL migrations with RLS and company isolation.
3. Configure production startup so it cannot silently use mock data or present unsaved records as persisted.
4. Run browser smoke tests for login, roles, company switching, proforma calculations, history, and key workflows.
5. Select a free hosting target that supports a private source repository and configure its deployment secrets safely.
6. Test access controls and document a manual export/recovery procedure before live business use.

## Free-plan operating approach
Use the existing Supabase Free project, keep the schema lean, retain migration files in version control, and make periodic manual exports before risky changes. No paid feature is required for staging work, but free-tier availability and recovery limitations must be accepted.
