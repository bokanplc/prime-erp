# Production module integration audit — 2026-11-06

Source reviewed: `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`
(91 section elements) and the current live Supabase public schema.

This is a source/schema inspection, not a browser end-to-end test. A module is
not marked production-ready merely because its screen or table exists.

## Module findings

| Module | Current integration evidence | Release assessment |
|---|---|---|
| Authentication / company membership | Supabase auth bridge reads active company memberships and profiles; role mapping is company-scoped | Needs real employee-account and browser OAuth tests |
| CRM | Dedicated production bridge reads/writes customers, activities, opportunities, after-sales tasks and controlled customer assignments | Schema-aligned; needs staff memberships and full browser tests |
| Sales documents | Source has limited read references, but does not call the available atomic create/approve/stock-posting RPCs | Not proven as a working sales document workflow |
| Purchasing | Supply bridge can read purchase orders, but the full purchase-document create/approve/receive workflow is not wired through its atomic RPCs | Not proven as a working purchasing workflow |
| Inventory | Legacy stock-entry/ledger screens still reference `stock_entries` and `stock_ledger`; profitability reads canonical `stock_movements` | Two stock representations are not yet reconciled; no movements or ledger rows exist |
| Supply & logistics | Dedicated bridge reads/writes inbound shipment plans and delivery controls | Partial: source itself says sales-demand integration and exception workflow are not enabled |
| Finance / GL | Production finance bridge reports counts for posted journal entries, AR/AP and periods; it is a dashboard adapter, not a complete finance entry/posting workflow | Not production-ready |
| HR / payroll | Production HR bridge reads counts from canonical `bokan_*` tables. Legacy HR forms still reference `employees`, `leave_requests`, `performance_reviews`, and `disciplinary_actions` | Not production-ready: legacy form CRUD is not mapped to canonical HR tables |
| Transaction costs | Dedicated company-scoped list/create bridge and profitability categories exist | Partial: browser tests, editing/audit controls and document allocation remain |
| Profitability | Reads posted sales documents, stock movements and transaction costs; separates landed gross profit and direct sales costs | Read-only report; depends on valid posted sales and stock data |
| Policy handbook | Reads active company policy document; print button is admin-only in UI | Content is present; verify browser print restrictions and employee role access |
| Private documents | Private company bucket and company-member storage policies exist | Partial: bucket is empty; upload, signed download and retention tests remain |

## Specific integration gaps found

1. The source-reviewed production allowlist is currently only
   `['policyhandbook']`. The staging config has production mode and
   full-data-ready disabled, blank browser Supabase credentials, and an empty
   enabled tab list. This is intentional fail-closed behavior.
2. The canonical live HR tables are `bokan_employees`,
   `bokan_leave_requests`, `bokan_performance_reviews`,
   `bokan_disciplinary_actions`, `bokan_attendance_records`, and
   `bokan_payroll_*`. The older HR form code still targets legacy table names
   `employees`, `leave_requests`, `performance_reviews`, and
   `disciplinary_actions`, which are not present in the live schema.
3. The legacy stock screens read/write `stock_entries` and `stock_ledger`,
   while the profitability report relies on `stock_movements`. These need one
   reconciled stock-posting path so a saved entry updates on-hand balances and
   cost of goods sold exactly once.
4. The supply bridge explicitly leaves sales-demand and exception workflows
   unimplemented.
5. The finance and HR production adapters are KPI/count readers. They do not
   constitute complete journal, subledger, payroll or approval CRUD.
6. The application source does not currently invoke the available atomic sales
   or purchase document creation / approval / stock-posting RPCs. Those RPCs
   also do not have authenticated EXECUTE grants after the public-function
   hardening migration. Do not grant them or expose UI until their intended
   browser contracts and role policies are reviewed and tested.

## Next implementation order

1. Finish canonical sales and purchasing document creation, approval and stock
   posting with one atomic transaction per workflow; no receipt/payment entry.
2. Reconcile stock_entries / stock_ledger with stock_movements and opening-stock
   movement support.
3. Replace HR legacy CRUD with canonical `bokan_*` tables and verify role policies.
4. Complete finance journal/subledger and payroll write/approval workflows.
5. Complete supply demand/exception controls, private document upload/download,
   and transaction-cost allocation.
6. Test CRM and policy handbook with real sales/data-entry accounts, then enable
   reviewed tabs only after browser and RLS tests pass.

No live schema, records, production flags, employee accounts, document statuses,
stock quantities, `main`, or production deployment were changed by this audit.
