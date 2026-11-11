# BOKAN ERP V7

A clean, modular rebuild of BOKAN ERP for Prime Investment Group and BlackRock Investment PLC.

## Engineering principles

- New architecture; V6.7 remains an untouched reference on its existing branch.
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

The application must not be treated as connected to a live database until the Supabase project URL, publishable key, Auth callbacks, migrations and RLS policies are configured and tested.

## Required environment

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

Never put a Supabase secret/service-role key in a `NEXT_PUBLIC_*` variable or browser bundle.

## Release rule

Preview deployments only until sign-in, company isolation, role permissions, persistence, auditability, backup/export and end-to-end workflows pass the release checklist. Never promote this branch to production automatically.