# BlackRock-only V6.7 — V22 corporate persistence migration map

**Checkpoint:** 2026-11-01  
**Working branch:** `feature/blackrock-only-v67`  
**Target company:** BlackRock Investment PLC only  
**Release status:** Preview only; production activation remains disabled.

## Verified live baseline

Read-only inspection of Supabase project `kafiwnuynjemufnankvi` confirms:

- 34 recorded migrations.
- 46 public base tables, all 46 with RLS enabled.
- 7 public compatibility/reporting views.
- 145 public RLS policies.
- Exactly one active company row: `BLACKROCK — BlackRock Investment PLC`.
- The full V6.7 HTML source has 42 distinct literal `.from('table')` references. Every referenced table or compatibility view exists in the live public schema.
- The current Vercel preview build is READY on `feature/blackrock-only-v67`; it is not a production deployment.

These checks prove object existence and RLS activation, not that every form, role path, RPC, report, or browser workflow is functionally correct.

## Confirmed remaining persistence gap

The V22 corporate-finance script still stores its records in one browser-local object:

`localStorage['blackrock_v22_corporate']`

Its state collections are `gl`, `ar`, `ap`, `bc`, `po`, `ic`, `fa`, `budget`, `payroll`, and `audit`. This is not durable server persistence and cannot be treated as production-ready.

## Canonical migration map

| V22 collection | Preferred durable model | Migration decision |
|---|---|---|
| `gl` | `ledger_accounts`, `fiscal_periods`, `journal_entries`, `journal_lines` | Replace the one-debit/one-credit local form with a balanced multi-line journal workflow. Post only through the validated `post_journal_entry` RPC; reverse only through `reverse_journal_entry`. Never write directly to posted ledger rows. |
| `ar` | `sales_documents`, `sales_document_items`, `sales_payments` | Use the canonical sales invoice and payment lifecycle. Do not create a parallel generic AR ledger. Add explicit payment allocation/aging behavior only where the current schema cannot represent it. |
| `ap` | `purchase_documents`, `purchase_document_items`, `supplier_payments` | Use canonical purchasing and supplier-payment records. Respect submitted/approved/received/part-paid/paid states and existing balance constraints. |
| `bc` | `company_bank_accounts` plus payment records; new bank-transaction/reconciliation model required | `company_bank_accounts` stores issuer/account details, not bank statement movements. Do not pretend it is a bank ledger. Design company-scoped bank transactions, statement imports, matching, and reconciliation before enabling this screen. |
| `po` | `purchase_documents`, `purchase_document_items`, `supply_shipments`, receiving/stock-posting workflow | Consolidate purchase order, receiving, supplier bill, and shipment linkage; do not duplicate the purchasing model. |
| `ic` | `products`, `stock_movements`, `inventory_stock_balances` | Use stock movements as the movement history and the balance view for derived on-hand quantities. Do not treat a browser-entered on-hand figure as an authorized stock adjustment. |
| `fa` | No dedicated fixed-asset register currently exists | Requires a new company-scoped asset register, depreciation schedule/posting, revaluation, and disposal workflow before activation. |
| `budget` | No dedicated budget/budget-line model currently exists | Requires company-scoped budgets, budget lines, period/account/cost-centre dimensions, approval state, and actual-versus-budget reporting. |
| `payroll` | `bokan_payroll_runs`, `bokan_payroll_lines`, `bokan_payroll_approvals` | Replace the generic employee/amount row with the existing HR/payroll model (gross, allowances, overtime, tax, employee/employer pension, deductions, net). Keep draft/approval/posting permissions separate. |
| `audit` | Existing domain histories plus a new append-only general audit-event model where required | The V22 “approval” list is not an audit trail. Do not let a user mark arbitrary audit rows approved. Record actor, company, entity, action, timestamp, and before/after context through trusted server-side writes. |

## Required implementation sequence

1. Keep the V22 tabs out of the production allowlist while their handlers still write to localStorage.
2. Migrate the general-ledger form first: load BlackRock accounts and fiscal periods from Supabase, validate at least two balanced lines, save/post through the trusted RPC, display server-returned records, and test reversal immutability.
3. Connect AR/AP and procurement screens to the canonical sales/purchasing document and payment workflows; remove the V22 duplicate local transaction arrays.
4. Connect inventory to products and stock movements; require controlled adjustments and reconcile derived balances.
5. Design and migrate bank reconciliation, fixed assets, budgets, and general audit events as explicit additive schema changes with RLS, grants, role checks, auditability, and tests.
6. Connect payroll to the existing HR/payroll schema and approval workflow; test HR/finance role boundaries and confidential data access.
7. Add authenticated browser tests for create/read/update/approve/post/reverse, unauthorized role attempts, and company-scope isolation before enabling any production tab.

## Data preservation and safety

- Do not automatically import or delete browser localStorage data. Existing browser-local records may belong to a real user; inventory/export and an owner-approved reconciliation are required before any import or cleanup.
- Do not create a second set of AR, AP, journal, purchasing, or stock tables where canonical tables already exist.
- Do not enable a tab merely because its table exists or its source compiles.
- Keep `PRODUCTION_MODE=false`, `FULL_ERP_DATA_READY=false`, and the production tab allowlist empty until the complete authenticated workflow tests pass.
- Do not merge the draft PR or promote a production deployment as part of this persistence planning step.

## Next engineering batch

Implement the V22 general-ledger adapter against the existing journal tables and trusted posting/reversal RPCs. Before changing the UI, verify the RPC payload contract and the current chart-of-accounts/fiscal-period records for BlackRock. The other V22 collections remain individually gated until their canonical workflows or required new models are complete.
