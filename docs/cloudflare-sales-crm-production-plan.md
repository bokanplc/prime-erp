# BOKAN Sales CRM — Cloudflare Production Hosting Plan

## Decision
Host the standalone BOKAN Sales Operations & CRM frontend on **Cloudflare Pages**. Do not use Vercel for this CRM and do not deploy it into the existing ERP project.

## Separation
- Dedicated Cloudflare Pages project: `bokan-sales-crm` (name suggestion).
- Independent Supabase project for CRM Auth and PostgreSQL. Never reuse BOKAN ERP, ERP V7, or WeHaul databases.
- Cloudflare Pages is hosting/CDN only; Supabase remains the CRM's authentication and database service unless the owner later changes that architecture.
- No demo data and no ERP stock, accounting, payment, or legacy sales imports.

## Cloudflare Pages settings (when the application is release-ready)
- Framework preset: **None / static site** for the current plain HTML prototype; revise only if the app is rebuilt with a framework.
- Build command: none (unless the production app adds a build step).
- Output directory: `sales-crm-prototype`.
- Root directory: repository root.
- Production branch: a reviewed release branch, not the draft prototype branch by default.
- Add custom domain only after production validation.

## Release blockers
The existing prototype is **not production-ready**. It uses browser local storage and includes a placeholder Proforma Maker. Before employee use, complete:
1. Dedicated Supabase project creation (owner must select organization).
2. Authentication, password reset, protected routes, roles, membership and invitation flow.
3. Database-backed shared records with RLS and organization/team-scoped policies.
4. Audit log, supervisor approval/return workflow and secure access controls.
5. Extract the original V6.7 Proforma Request and Proforma Maker; verify the original styling, fields, calculations, print behavior and functionality.
6. Remove/avoid all ERP data imports and demo records.
7. Test on desktop and mobile, including role-based scenarios, request assignment, maker handoff, supervisor reviews and reports.
8. Security review, build validation and release checklist.
9. Deploy to Cloudflare Pages, verify the production URL, then invite employees.

## Approved UI direction
Use the approved corporate navy and blue-gray palette, white content surfaces, cool-gray backgrounds, clean typography, subtle borders, polished dashboard cards, charts/visuals, responsive layouts. CRM design is fresh; the V6.7 proforma forms are retained as the exact source-of-truth exceptions.
