# BOKAN ERP V7 implementation status

Last updated: 2026-11-11

## Isolated environment

- New Supabase project: `BOKAN ERP V7`
- Project reference: `thfzvtltmaieesjulggr`
- New Vercel project: `bokan-erp-v7`
- Working branch: `rebuild/bokan-erp-v7`
- No V6.7 database, storage bucket, customer, supplier, product, stock or transaction data has been imported.
- The V7 database has no seeded business records or employee accounts.
- Supabase was created on the Free plan with a $0 monthly confirmation at provisioning. Free-plan quotas and inactivity pausing still apply.

## Implemented in the V7 branch

| Area | Implemented capability |
|---|---|
| Dashboard | Live company-scoped customer, pipeline, approved sales and task metrics |
| CRM | Customer directory, leads, pipeline stages, estimated value, follow-up dates, calls, visits, meetings and reminders |
| Sales | Quotations, proformas, sales orders, customer-specific and general product prices, line discounts, 15% VAT, manager approval, direct sales costs and A4 print/PDF view |
| Purchasing | Suppliers, products, purchase-price history, purchase requests, purchase orders, manager approval, printable purchase orders and direct purchase costs |
| Profitability | VAT-normalized revenue, transaction-level landed gross profit, direct-cost deductions and purchase-side cost visibility |
| Logistics | Delivery planning, carrier/vehicle details, dispatch, delivery confirmation and exception status |
| Tasks | Company-scoped tasks and reminders with due dates and status updates |
| Documents | Private company-folder storage, upload metadata, business-record links and expiring signed downloads |
| Reports | Live CRM, sales document, activity, purchasing and task summaries |
| Administration | Company membership list, existing-account assignment, role management and member activation/deactivation |

## Explicitly excluded

- HR and payroll
- General ledger, journals, accounting and bank reconciliation
- Customer receipts and supplier payments (continue in Peachtree)
- Stock posting, purchase receiving, stock balances and inventory valuation
- Legacy transaction imports and opening-stock reconciliation

## Database controls

- 23 ordered V7 migrations are tracked in the repository and applied to the isolated V7 project.
- Public business tables have row-level security enabled and forced.
- Same-company composite foreign keys protect cross-table relationships.
- Private document storage uses company membership policies.
- Database triggers enforce manager-only approval of sales documents and purchase orders and protect issued-document status transitions.
- Data-entry users can record purchasing source data but cannot approve commercial documents.
- Creator-scoped cleanup policies allow safe rollback of incomplete first-save records.
- Commercial VAT and margin calculations have unit tests.
- PostgreSQL smoke tests cover tenant isolation, private storage, data-entry permissions, manager approvals, membership administration and excluded modules.

## Remaining release gates

1. Complete the latest CI run after the current changes.
2. Deploy the latest verified commit to a Vercel Preview deployment and review it.
3. Create/invite the first account in V7 Supabase Auth.
4. Run `scripts/v7-initial-admin-bootstrap.sql` with that account's email to create the two company records and grant initial admin access.
5. Add the three sales users and one data-entry user after their V7 Auth accounts exist.
6. Complete authenticated end-to-end tests for both companies and the four employee roles.
7. Verify sign-in/session refresh and approved redirect URLs.
8. Review the Preview with the owner before any production promotion.
9. Back up and verify V7 before considering V6.7 decommissioning. V6.7 remains untouched.

## Release rule

The V7 branch and database are not yet an employee production release. Do not promote to Vercel Production, change `main`, or delete V6.7 until the release gates above are satisfied and the owner has reviewed the Preview.
