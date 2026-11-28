# BOKAN Sales CRM App
Standalone static frontend for the independent Supabase project BOKAN Sales CRM. No ERP, inventory, or accounting integration.

## Cloudflare Pages
Create a dedicated Cloudflare Pages project (suggested: `bokan-sales-crm`), connect repository `bokanplc/prime-erp`, branch `feature/v67-remove-sales-crm-extraction`, root directory `sales-crm-app`. Static HTML; build command blank; output directory `.`. Use HTTPS and add custom domain after verification.

## Implemented in this frontend
- Supabase email/password auth UI, sign-up, sign-in and password-reset initiation.
- First-owner bootstrap via single-use database RPC.
- Shared authenticated CRUD/updates (RLS protected) for leads, call activity, visits, tasks, proforma requests/items, daily reports.
- Stage and request status changes; task completion; basic dashboard and activity counts.
- No demo records.

## Remaining before production release
- Cloudflare deployment and live browser smoke tests.
- SMTP / auth confirmation and password reset redirects verify.
- Team invite/admin roster, safe user assignment, manager daily-review actions, stronger UI role gates.
- Extract original V6.7 Proforma Maker and verify print, calculations, persistence.
- Review and test all policies with multiple roles, accessibility/mobile QA, audit coverage (triggers currently cover leads/tasks/requests).
