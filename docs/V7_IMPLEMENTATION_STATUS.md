# BOKAN ERP V7 implementation status

Last updated: 2026-11-16

## Isolated environment

- New Supabase project: `BOKAN ERP V7`
- Project reference: `thfzvtltmaieesjulggr`
- New Vercel project: `bokan-erp-v7`
- Working branch: `rebuild/bokan-erp-v7`
- No V6.7 database, storage bucket, customer, supplier, product, stock or transaction data has been imported.
- Live verification on 2026-11-16: 20 public base tables; RLS enabled and forced on 20/20; 33 migrations applied; one invited, email-confirmed Auth account; one active `admin` membership for BlackRock Investment PLC; zero employee accounts and zero operational business rows.
- Supabase was created on the Free plan with a $0 monthly confirmation at provisioning. Free-plan quotas and inactivity pausing still apply.

## Company boundary

- Sole tenant: **BlackRock Investment PLC**.
- Address: Meskel Flower, Addis Ababa.
- Telephone: 978 23 48 20.
- Base currency: ETB; VAT default: 15%.
- Prime Investment Group is decommissioned and is not a V7 company or workspace.
- The initial invited and email-confirmed account currently has one active `admin` membership. No employee accounts have been created or invited.

## Implemented in the V7 branch

| Area | Implemented capability |
|---|---|
| Dashboard | Live company-scoped customer, pipeline, approved sales and task metrics |
| CRM | Editable customer profiles, linked sales history, leads, pipeline stages, estimated value, follow-up dates, calls, visits, meetings and reminders |
| Sales | Quotations, proformas, sales orders, customer-specific and general product prices, line discounts, 15% VAT, manager approval, direct sales costs and A4 print/PDF view |
| Purchasing | Suppliers, products, general and supplier-specific purchase-price history, purchase requests, manager approval and conversion to linked purchase orders, printable purchase orders and direct purchase costs |
| Profitability | VAT-normalized revenue, transaction-level landed gross profit, direct-cost deductions and purchase-side cost visibility |
| Logistics | Delivery planning, carrier/vehicle details, dispatch, delivery confirmation and exception status |
| Tasks | Company-scoped tasks and reminders with due dates and status updates |
| Documents | Private company-folder storage, upload metadata, business-record links and expiring signed downloads |
| Reports | Live CRM, sales document, activity, purchasing, task and salesperson performance summaries |
| Audit log | Read-only, company-scoped history of business changes and approvals |
| Notifications | Recipient-only in-app alerts for pending approvals, approvals and request conversion; unread state is immutable except for marking read |
| Administration | Company identity and VAT settings, company membership list, existing-account assignment, role management and member activation/deactivation |

## Explicitly excluded

- HR and payroll
- General ledger, journals, accounting and bank reconciliation
- Customer receipts and supplier payments (continue in Peachtree)
- Stock posting, purchase receiving, stock balances and inventory valuation
- Legacy transaction imports and opening-stock reconciliation

## Database controls

- 33 ordered V7 migrations are tracked in the repository and applied to the isolated V7 project.
- Public business tables have row-level security enabled and forced.
- Same-company composite foreign keys protect cross-table relationships.
- Private document storage uses company membership policies.
- Database triggers enforce manager-only approval of sales documents and purchase orders and protect issued-document status transitions.
- Data-entry users can record purchasing source data but cannot approve commercial documents.
- Creator-scoped cleanup policies allow safe rollback of incomplete first-save records.
- Commercial VAT and margin calculations have unit tests.
- PostgreSQL smoke tests cover tenant isolation, private storage, data-entry permissions, manager approvals, membership administration and excluded modules.

## Verified state and remaining release gates (2026-11-16)

- Latest verified application/test commit: `f18752e80bfb2fd341ae0c4c1e645dc82fb139dc`.
- GitHub Actions run [#358](https://github.com/bokanplc/prime-erp/actions/runs/43845238522) completed successfully for that commit. Both `verify` and `database-migration-smoke` passed, including lint, production build, migration application in disposable PostgreSQL, RLS, tenant isolation and private-upload cleanup tests.
- Supabase project `thfzvtltmaieesjulggr` currently reports `ACTIVE_HEALTHY`; live migration history contains 33 migrations.
- A read-only catalog check reconfirmed 20 public base tables, RLS enabled and forced on all 20, and 74 public policies.
- Security advisor: one warning, leaked-password protection disabled. Performance advisor: 46 informational unused-index notices. Health advisor: no findings.
- No operational business data has been imported or seeded. The user's fresh reconciled dataset remains pending.
- Authenticated browser acceptance remains unverified. Automated CI is not browser acceptance.
- Vercel work is paused at the owner's direction; no deployment or project settings were changed during this checkpoint.

Remaining gates:
1. Complete real authenticated browser acceptance for login, session refresh, navigation, persistence, private document access and authorization boundaries.
2. Verify sales and data-entry permission paths using controlled test identities; do not create/invite employee accounts without separate approval.
3. Resolve or explicitly accept the leaked-password-protection warning through an approved Auth-setting change.
4. Reconcile the security checklist with evidence and preserve untested items as open.
5. Owner review of Preview before any production release. Production promotion, `main` changes and employee distribution remain separate release actions.

## Release rule

The V7 branch and database are not yet an employee production release. Do not promote to Vercel Production, change `main`, or delete V6.7 until the release gates above are satisfied and the owner has reviewed the Preview.
