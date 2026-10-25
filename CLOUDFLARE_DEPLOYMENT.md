# Prime ERP — Cloudflare Pages deployment

This repository is a static HTML application and can be deployed on Cloudflare Pages without a build step.

## Connect the repository

1. Sign in to Cloudflare and open **Workers & Pages**.
2. Choose **Create application** → **Pages** → **Connect to Git**.
3. Connect the GitHub account that owns `bokanplc/prime-erp` and select this repository.
4. Use `main` as the production branch.
5. Framework preset: **None** (or **Static HTML** if shown).
6. Build command: leave empty.
7. Build output directory: `/` (repository root).
8. Save and deploy. Future commits to `main` should trigger deployments automatically.

## Before using for business operations

- Confirm the site loads over HTTPS and the browser console has no errors.
- Confirm the Supabase URL and publishable key are correct. A publishable/anon key may be present in frontend code; never put a Supabase service-role key in the browser.
- Verify Supabase Auth, membership assignment, and Row Level Security using separate test accounts before adding real company data.
- Email confirmation and administrator provisioning are still pending. Do not treat this starter as production-ready until access and permissions are tested.
- Cloudflare's free limits and terms can change; check the current Cloudflare plan terms for the intended commercial use.

## Current application scope

The current `index.html` contains sign-in/sign-up, company workspace selection, customer and product forms, and basic sales document headers. Sales line-item editing, printable document templates, and administrator-managed user provisioning are not yet complete.
