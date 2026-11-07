# V6.7 Production Persistence Matrix — 2026-11-06

Source audited: `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` (879,266 bytes; 9,938 lines; 91 tab panels at the time of audit).

This is a source-level inventory of production adapters, not a statement that every module is release-ready.

## Production bridge coverage found in source

| Area | Source adapter | Current behavior | Remaining gate |
|---|---|---|---|
| Authentication / company context | `bokan-v61-production-auth` | Supabase Auth, active company membership lookup, role mapping, selected-company context | Real staff sign-in and role-by-role browser verification |
| CRM | `bokan-v63-crm-production-bridge` | Company-scoped customer, activity, opportunity, after-sales task reads/writes; owner reassignment uses RPC | Confirm all legacy CRM screens consistently use bridge; test real sales memberships, RLS and reminders |
| Supply & Logistics | `bokan-v64-supply-production-bridge` | Company-scoped shipment and delivery controls; reads linked purchase/sales documents | This is not purchase receiving or stock allocation; demand and exception workflows remain unimplemented |
| Finance | `bokan-v65-finance-production` | Reads ledger, receivable/payable document counts and fiscal periods; journal posting uses RPC | Test journal posting, account/period rules and permissions; receipts/payments intentionally stay in Peachtree |
| Transaction costs | `bokan-v69-transaction-costs` | Company-scoped transaction-cost list/create | Verify category mapping, direct/landed allocation and edit/audit workflow |
| Profitability | `bokan-v70-profitability-report` | Reads posted invoices, stock movement costs and transaction costs | COGS cannot be accepted until stock issues carry valid cost and landed-cost allocation is defined |
| Policy handbook | `bokan-v71-policy-handbook` | Reads active company policy document; admin-only print UI | Verify staff read access and server-side controls for document changes/printing |

## Important source findings

- The source contains a mock Supabase implementation and many legacy `localStorage` stores. These must remain inaccessible in hosted production mode.
- The production tab review allowlist in the source currently contains only `policyhandbook`. The configuration must not broaden that allowlist until each module is reviewed.
- The source contains no browser RPC calls for `post_sales_document_stock` or `receive_purchase_document`.
- Existing RPC calls in the inspected source include proforma operations, CRM owner reassignment, and journal posting. This is not evidence of working sales stock posting or purchase receiving.
- Legacy dashboards, enterprise control panels, stock ledgers, purchasing screens, finance screens, and HR screens contain local-storage-based state and/or old table access. They are not automatically production-ready because they are visible in the V6.7 interface.
- The HR bridge exists in source, but HR is explicitly deferred from the first release and must remain outside the enabled production tab allowlist.

## First-release work order

1. Complete canonical purchasing and stock receiving, including a reconciled migration for the missing live RPC.
2. Agree and implement inventory valuation before enabling any sales stock issue.
3. Build the sales-document browser bridge around approved create/submit/approve/post RPC contracts; do not use direct browser writes to bypass posting controls.
4. Reconcile the legacy stock reports and swap screens to the canonical stock movement ledger. Do not silently import old localStorage or sample records.
5. Verify CRM end-to-end with real users and sales-team membership records.
6. Complete transaction-cost edit/audit and landed-cost allocation rules; verify both profitability measures.
7. Verify policy handbook employee read and admin controls.
8. Exclude HR, payment-entry, and demo/local-storage modules from the initial production allowlist.

## Release guard

No source-level adapter or visible tab should be considered production-ready solely because it has a Supabase client. A module is eligible only after data contract, RLS, role permissions, error handling, and authenticated browser tests pass against the live schema.
