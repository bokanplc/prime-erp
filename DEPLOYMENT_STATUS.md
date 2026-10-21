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
- The current ERP review HTML is not yet installed in this repository branch, and the app is not live.

## Next steps
1. Add the reviewed full ERP source to this branch without replacing `main`.
2. Extract and validate the application's actual database contract.
3. Prepare least-privilege SQL migrations with RLS and company isolation.
4. Review migrations and application configuration before applying any schema changes.
5. Run syntax checks and browser smoke tests; verify production mode cannot silently use mock data.
6. Deploy only after the above checks pass.

## Free-plan operating approach
Use the existing Supabase Free project, keep the schema lean, retain migration files in version control, and make periodic manual exports before risky changes. No paid feature is required for staging work, but free-tier availability and recovery limitations must be accepted.
