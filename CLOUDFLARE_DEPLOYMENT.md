# BOKAN ERP — Cloudflare deployment guide

This repository contains a static HTML application. There is no build step. The production host is managed separately in Cloudflare; GitHub stores the source code and runs validation.

## Current release

- Repository: `bokanplc/prime-erp` (private)
- Production branch: `main`
- Entry point: `index.html`
- Static response headers: `_headers`
- Automated source validation: `.github/workflows/validate.yml`
- Supabase project: `kafiwnuynjemufnankvi` (EU Central)
- Intended live address: `https://prime-erp.bokanplc.workers.dev`

A successful GitHub Actions run confirms source-level checks only. It does not prove that Cloudflare deployed the newest commit or that the app works in a real browser.

## Cloudflare deployment configuration

The intended setup is a static site deployment from the GitHub repository:

1. Open Cloudflare **Workers & Pages** and select the existing application (or create a Pages application if this is not already configured).
2. Connect GitHub repository `bokanplc/prime-erp`.
3. Production branch: `main`.
4. Framework preset: **None**.
5. Build command: leave blank.
6. Build output directory: repository root (`/`).
7. Save and deploy.

Important: the currently shared production address uses the `workers.dev` hostname. If the existing deployment is a Cloudflare Worker with a static-assets binding rather than Pages, keep its current product type and configure the existing Git integration/build command to serve the repository root. Do not create a duplicate deployment or change the production URL just to match this guide.

## What GitHub does

- Every push to `main` or `staging`, and every pull request targeting `main`, triggers a Node.js syntax and content validation workflow.
- The workflow checks core forms, BOKAN ERP branding, the public Supabase key pattern, absence of common server-side key markers, and the atomic sales-document RPC integration.
- The workflow is not a Cloudflare deployment pipeline and does not test login, email delivery, database policies in a browser, or live-host freshness.

## Supabase configuration

- Project URL is configured in the frontend in `index.html`.
- A publishable key is expected in frontend code; it is not a secret. Never place a service-role key, database password, or secret key in client-side HTML.
- The application uses individual Supabase Auth accounts and company memberships protected by row-level security.
- The sales-document function `public.create_sales_document_with_items(jsonb,jsonb)` inserts the document and its line items in one database transaction under caller permissions.
- Password reset uses a redirect to the current site origin with `/?reset-password=1`. Supabase Auth **Site URL** and allowed redirect URLs must include the real production origin and this path. Those dashboard settings still need an owner-side check.
- Supabase Auth currently reports that leaked-password protection is disabled. Review Auth password-security settings before production-critical use.

## Post-deployment smoke test

Use the live URL and test with a real authorized account, without adding dummy records to production:

1. Confirm the page title and header show **BOKAN ERP**.
2. Confirm the browser loads the Supabase client and shows the service as configured.
3. Sign in and verify the assigned company workspaces are listed.
4. Open Customers, Products, and Sales documents; confirm lists load and no console/API errors appear.
5. If using a designated test company, create a test customer/product and a quotation with at least one line item. Confirm subtotal, tax, discount, grand total, and saved document are correct.
6. Confirm the new document appears in the list and belongs only to the selected company.
7. Sign out and verify the workspace is no longer accessible.
8. Test password reset only after confirming the Supabase redirect configuration and email delivery.

If no dedicated test company is available, skip creation of records and use read-only checks only.

## Release limitations

The current app is an early sales-workflow foundation, not a complete ERP. Printable/PDF documents, edit/delete workflows, stock control, purchasing, payments, accounting, reports, and administrator-managed user provisioning remain unfinished. Do not represent these modules as available. Confirm backups, permissions, business terms, and real-browser behavior before relying on the app for critical business operations.
