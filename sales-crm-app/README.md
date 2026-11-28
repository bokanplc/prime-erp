# BOKAN Sales CRM App
Standalone sales CRM frontend for the independent Supabase project **BOKAN Sales CRM**. It has no ERP, stock, or accounting integration.

## Cloudflare Pages configuration
- Dedicated Cloudflare Pages project: suggested name `bokan-sales-crm`.
- Git repository: `bokanplc/prime-erp`.
- Branch: `feature/v67-remove-sales-crm-extraction`.
- Root directory: `sales-crm-app`.
- Build command: blank (static HTML).
- Output directory: `.`.
- HTTPS enabled; add custom domain after smoke testing.

## Implemented
- Supabase email/password sign-in, sign-up, and password reset initiation.
- Single-use first-owner bootstrap RPC.
- Shared RLS-protected data operations for leads/pipeline, calls, visits, tasks, proforma requests/items, and daily reports.
- Lead stage changes, request status updates, task completion, live dashboard counts and performance totals.
- Team invitation form + deployed `crm-invite-member` Supabase Edge Function. Server validates caller membership/role, sends an auth invitation, and creates membership. Owner can invite supervisors; supervisors/managers may invite junior/senior sales roles.
- Audit triggers for lead, task and proforma-request changes.
- No demo data.

## Release still pending
- Cloudflare Pages deployment and browser QA (not deployed yet).
- Verify auth email confirmation, SMTP and redirect URL settings.
- Multi-role permission testing and RLS checks.
- Safe employee roster, manager daily-report review actions and role-gated navigation.
- Exact V6.7 Proforma Request and Maker extraction/review, with calculations/print/save tested.
- Audit coverage expansion, mobile/accessibility checks, and production smoke testing.
