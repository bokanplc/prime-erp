# BOKAN Sales CRM — Production Release Checklist

## Current confirmed state
- Dedicated Supabase project: `vxxkpllqqxnqrtxkjjbh` (healthy).
- Company/workspace row: BlackRock Investment Plc (one row).
- CRM data is clean: 0 members, 0 leads, 0 proforma requests; no demo data.
- All ten `crm_*` tables have RLS policies.
- Owner bootstrap RPC is restricted to signed-in users: `anon` cannot execute; `authenticated` can execute.
- Audit triggers exist for leads, tasks, and proforma requests.
- Supabase Edge Function `crm-invite-member` is active.
- CRM static frontend is in `sales-crm-app/`; baseline security headers are in `sales-crm-app/_headers`.
- The frontend branch is `feature/v67-remove-sales-crm-extraction`.

## Release blockers (must complete before public production use)
1. Extract and integrate the V6.7 Proforma Request + Maker features into the standalone CRM; test calculations, print, save, edit, and history.
2. Verify sign-up, email confirmation, reset links, SMTP delivery, and redirect URLs in Supabase Auth.
3. Finish role-aware controls and supervisor review actions; verify authorization in database policies, not only UI hiding.
4. Test call, visit, lead, task, daily-report, and proforma workflows with separate test users for Owner, Supervisor, Junior, and Senior.
5. Browser QA (desktop and mobile), accessibility checks, and error handling.
6. Deploy to Cloudflare Pages and run a live smoke test. Deployment has not been performed; no production URL exists yet.

## Deployment target
Cloudflare Pages project name suggestion: `bokan-sales-crm`.
Repository: `bokanplc/prime-erp`.
Branch: `feature/v67-remove-sales-crm-extraction`.
Root directory: `sales-crm-app`.
Build command: none (static HTML).
Output directory: `.`.

Do not call this release production-ready until all blockers above are closed and live tests pass.
