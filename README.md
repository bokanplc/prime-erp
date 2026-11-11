# BOKAN ERP V7

A clean, modular rebuild of BOKAN ERP for Prime Investment Group and BlackRock Investment PLC.

## Engineering principles

- V7 is isolated from V6.7: no legacy runtime, HTML app, deployment config, credentials, database, or business data is loaded or called.
- Next.js on Vercel, with Supabase Auth and PostgreSQL as the application data boundary.
- Company membership and role authorization enforced by database RLS, never by client-supplied role/company values.
- No demo records or mock persistence in hosted environments.
- No historical business-data import as part of the rebuild. Fresh, reconciled data will be loaded separately after workflows are verified.
- Customer receipts and supplier payments remain in Peachtree and are not ERP modules.
- HR is deferred.
- Inventory opening balances, historical stock posting, stock receiving and inventory costing are excluded from this first product scope.

## Product modules

1. Home dashboard and company switcher
2. CRM: customers, leads, pipeline, calls, visits, reminders, activity history and salesperson performance
3. Sales: quotations/proformas, sales documents, pricing, discounts, VAT presentation and lifecycle controls
4. Purchasing: suppliers, purchase requests/orders and purchase price capture (without payment processing)
5. Commercial profitability: landed gross profit and profit after direct sales costs
6. Direct costs: transportation, loading and miscellaneous transaction-linked costs
7. Logistics and delivery coordination
8. Documents, notifications, reports and audit history
9. Administration: users, company memberships, roles and settings

## Local development

Requires Node.js 20.9+.

```bash
npm install
cp .env.example .env.local
npm run dev
```

V7 must never be connected to the V6.7 Supabase project or legacy business tables. The V7 environment must be separately provisioned. The application must not be treated as connected to a live database until the Supabase project URL, publishable key, Auth callbacks, migrations and RLS policies are configured and tested.

## Required environment

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

Never put a Supabase secret/service-role key in a `NEXT_PUBLIC_*` variable or browser bundle.

## Legacy application boundary

- The V7 branch intentionally removes the legacy Cloudflare/Wrangler deployment configuration.
- Vercel is the only deployment target for V7.
- Legacy V6.7 files may remain in the repository's historical branch for archival continuity, but they are excluded from V7 deployment packaging and are not imported, built, or executed.
- The V6.7 production service is not shut down by a V7 branch change. Decommissioning the live service requires a separate, explicit cutover decision after V7 is production-ready.

## Release rule

Preview deployments only until sign-in, company isolation, role permissions, persistence, auditability, backup/export and end-to-end workflows pass the release checklist. Never promote this branch to production automatically.