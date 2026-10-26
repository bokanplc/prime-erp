# BOKAN ERP V6.7 — Cloudflare Workers Builds Settings (Review Only)

**Status: configuration guidance. The connected Cloudflare project is a Workers service, not a Pages project. No production deployment has been approved.**

## Required repository-side behavior

The full review source is under `staging/`; do not publish that directory directly. Run the branch-aware build script to generate `dist/release/`.

- Workers Builds sets `WORKERS_CI_BRANCH`; the builder uses it to recognize `deploy/secure-staging`.
- `CF_PAGES_BRANCH` is also supported for compatibility if this artifact is later built by Pages.
- On `deploy/secure-staging`, the build emits the complete V6.7 review interface with clearly labeled sample/demo data, `DEMO_REVIEW_MODE: true`, blank Supabase credentials, and noindex/no-store headers.
- On other branches, it emits the sanitized, fail-closed candidate with demo mode disabled.
- `wrangler.jsonc` points Cloudflare Workers Static Assets at `./dist/release`; the Worker name is `prime-erp` to match the connected Cloudflare service.

## Cloudflare Workers > Settings > Builds

| Setting | Value |
|---|---|
| Root directory | Repository root (`/`) |
| Build command | `node scripts/build-release-candidate.mjs` |
| Preview command | `npx wrangler preview` |
| Production branch | `main` |
| Preview builds | Enabled for non-production branches |

The build command must be configured in the Cloudflare dashboard. A Git push alone does not change dashboard build settings. Once saved, the next build should use the latest branch commit. Verify the log reports the configured build command and the expected commit SHA before trusting the preview.

Do not change the production branch to `deploy/secure-staging`. Keep the pull request draft and unmerged. The intended review target is a branch preview, not the active production deployment.

## Security and readiness limits

This is a UI review surface only. It contains demo/sample data and is not a security boundary for real company data. Do not enter real customer, employee, payroll, accounting, tax, or financial records. Supabase credentials remain blank and the app is not connected to live Supabase.

The ERP remains **STOP-SHIP** for production until all schema, persistence, authentication, company-isolation, RLS/grants, private document storage, and end-to-end workflow gates are completed and independently verified. No live Supabase changes, PR merge, production promotion, paid upgrade, or secret changes are authorized by this configuration work.

Official references:
- Workers Builds configuration: https://developers.cloudflare.com/workers/ci-cd/builds/configuration/
- Workers branch/preview builds: https://developers.cloudflare.com/workers/ci-cd/builds/build-branches/
- Workers Static Assets: https://developers.cloudflare.com/workers/static-assets/
