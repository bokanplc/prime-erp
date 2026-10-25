# BOKAN ERP

BOKAN ERP is a multi-company sales-workflow application for BlackRock Investment PLC and Prime Investment Group.

## Current capabilities

- Supabase email/password sign-in and account registration
- Company workspace selection based on active company memberships
- Customer directory: create and list customers
- Product catalogue: create and list products
- Draft quotations, proforma invoices, sales orders, and invoices
- Sales document line items with quantity, unit, unit price, tax percentage, and automatic totals
- Atomic database save for a sales document and its line items
- Responsive single-page interface

## Not yet implemented

This is not yet a complete ERP or accounting package. PDF/print templates, editing/deleting records, stock/inventory, purchasing, payments, accounting ledgers, reports, and full administrator-managed user provisioning remain future work.

## Architecture

- Frontend: `index.html`, plain HTML/CSS/JavaScript
- Backend/auth/database: Supabase
- Source control and validation: GitHub private repository
- Production hosting: existing Cloudflare-hosted address, managed separately from GitHub

## Development and release flow

1. Make application changes on a working branch, not directly on `main`.
2. Open a pull request to `main`.
3. Review the change and ensure the **Validate BOKAN ERP** GitHub Actions workflow passes.
4. Merge only after checking the change is safe for the live application.
5. Confirm Cloudflare has deployed the exact `main` commit; GitHub CI does not prove live deployment.
6. Run the smoke test in [CLOUDFLARE_DEPLOYMENT.md](CLOUDFLARE_DEPLOYMENT.md).

## Important configuration

- Supabase project ref: `kafiwnuynjemufnankvi`
- Production origin currently intended: `https://prime-erp.bokanplc.workers.dev`
- Supabase Auth redirect configuration must match the real production origin for password reset to work.
- The browser must only contain a Supabase publishable key. Never commit service-role keys, database passwords, email credentials, or other secrets.

## Documentation

- [Cloudflare deployment and smoke-test guide](CLOUDFLARE_DEPLOYMENT.md)
- [Security guidance](SECURITY.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
