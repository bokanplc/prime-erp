# BOKAN ERP V6.7 — Full Module Completeness Matrix

**Re-scanned from the staged source and candidate schema files on 2026-10-27.**  
**Status: STOP-SHIP. This is a readiness inventory, not production approval.**

## Current coverage

- Distinct logical table names referenced by the full V6.7 source: **57**
- Table definitions across the legacy first-slice draft plus the new UUID-company Proforma candidate: **6** distinct names
- Logical names not represented in those schema source files: **51**
- Required legacy API endpoint groups: login, change-password, logout, bootstrap, store. These are not implemented in the repository's expected Cloudflare Pages Functions paths.
- Production mode: disabled.
- Full ERP data readiness: disabled.
- Supabase production project: 12 public tables and 15 applied migration records (see `docs/LIVE_SCHEMA_RECONCILIATION_2026-10-26.md`).

The full ERP is **not** ready for deployment as a working application. A green source/test workflow means the reviewed source guards and the first-slice proforma schema tests passed; it does not mean the other ERP modules have database persistence.

## Schema-covered first slices (not applied to live)

| Table | Source file / scope |
|---|---|
| `companies` and `profiles` | Legacy draft only; **incompatible** with the current live UUID `companies` + `company_memberships` identity model. Do not apply that candidate unchanged. |
| `company_proforma_settings` | New UUID-company candidate; issuer TIN/address/phone maintained through an authorized RPC. |
| `company_bank_accounts` | New UUID-company candidate; company-ID-scoped read-only browser access; production edits fail closed. |
| `custom_terms` | New UUID-company candidate; company-ID-scoped reads and validated inserts. |
| `proformas` | New UUID-company candidate; server-calculated totals, immutable revision rows, issuer/bank snapshots, atomic numbering/save. |

The older five-table draft has historical disposable PostgreSQL tests, and the new UUID-company candidate now has its own static and PostgreSQL 17 test suite wired into CI. The latest new workflow result is not yet verified. Neither candidate has been applied to the connected live Supabase project.

## Referenced tables not represented in these candidate schema files

- `bokan_ap_bills`
- `bokan_ap_payments`
- `bokan_ar_invoices`
- `bokan_ar_receipts`
- `bokan_attendance_records`
- `bokan_customer_activities`
- `bokan_customer_assignments`
- `bokan_customers`
- `bokan_delivery_events`
- `bokan_delivery_order_lines`
- `bokan_delivery_orders`
- `bokan_employees`
- `bokan_factories`
- `bokan_fiscal_periods`
- `bokan_goods_receipts`
- `bokan_inventory_balances`
- `bokan_inventory_movements`
- `bokan_journal_entries`
- `bokan_leave_requests`
- `bokan_logistics_exceptions`
- `bokan_payroll_approvals`
- `bokan_payroll_lines`
- `bokan_payroll_runs`
- `bokan_performance_reviews`
- `bokan_purchase_order_lines`
- `bokan_purchase_orders`
- `bokan_purchase_request_lines`
- `bokan_purchase_requests`
- `bokan_sales_opportunities`
- `bokan_salespeople`
- `bokan_shipment_containers`
- `bokan_shipments`
- `bokan_stock_reservations`
- `bokan_warehouses`
- `customer_billings`
- `customer_logs`
- `customers`
- `disciplinary_actions`
- `documents`
- `employees`
- `expenses`
- `leave_requests`
- `notifications`
- `per_diem_requests`
- `performance_reviews`
- `sales_targets`
- `stock_entries`
- `stock_ledger`
- `trip_plans`
- `visit_reports`

This is a repository schema-source coverage list, not a live-schema inventory. In particular, `company_memberships` and `customers` already exist in the live Supabase schema but their live definitions are not included in these candidate files; they still require field-level reconciliation with the source. Some duplicate-looking legacy/new models must be reconciled before their tables are created. Do not blindly create all names independently.

## Required backend still missing

The legacy adapter calls:
- `/api/auth/login`
- `/api/auth/change-password`
- `/api/auth/logout`
- `/api/bootstrap`
- `/api/store/*`

The current repository does not implement the corresponding Cloudflare Pages Functions groups. Static Pages hosting will not supply them automatically. The hosted adapter is intentionally fail-closed until those modules are migrated to the Supabase-backed path or a properly authenticated API is built.

## What the readiness gate does

`scripts/audit-erp-release-readiness.mjs` is now part of CI. It prints the missing schema/API coverage while production remains disabled. If either `PRODUCTION_MODE` or `FULL_ERP_DATA_READY` is changed to `true` while blockers remain, it fails the build.

## Release condition

Do not turn on full ERP mode or deploy this candidate as a functioning production ERP until:
1. Canonical data models and company-membership rules are approved.
2. Each enabled module has a complete schema, grants, RLS, constraints and trusted write paths.
3. The legacy API dependency is removed or implemented securely.
4. Private document storage and signed downloads are implemented.
5. Real browser/Auth/Data API tests pass for both PRIME and BlackRock.
6. Business records are reconciled and export/recovery has been rehearsed.


## Live Supabase cross-check — 2026-10-26

A current read-only inspection of the connected Supabase project has now found an applied 12-table sales/procurement/inventory foundation and 15 recorded migrations. This differs from the earlier historical statements in this matrix that the live project has no applied tables or migrations; the earlier statement was true at its check date, but is stale now.

Observed live public tables (RLS reported enabled on each): companies (2 rows), company_memberships (2), customers (0), products (0), sales_documents (0), sales_document_items (0), suppliers (0), purchase_documents (0), purchase_document_items (0), stock_movements (0), sales_payments (0), supplier_payments (0).

Important counting distinction: the reported 55 source-referenced logical names and 50 missing table definitions refer to comparison against the current five-table first-slice schema draft. Those counts do not mean that the live project has only five tables or that exactly 50 live tables are missing. Some business areas overlap with the live 12-table foundation, but the full source-to-live contract, exact column compatibility, authorization, and workflow coverage have not yet been proven.

The live identity schema uses companies plus company_memberships (company_id/user_id/role/is_active), while the first-slice Proforma candidate defines companies plus profiles (company_code/role). Do not apply that candidate as-is to live Supabase. First reconcile tenant identity/membership, proforma ownership/numbering, grants/RLS, and live migration SQL.

See docs/LIVE_SCHEMA_RECONCILIATION_2026-10-26.md and the matching checkpoint appended to DEPLOYMENT_STATUS.md for the complete read-only facts, the 15 migration names, current Vercel/Cloudflare evidence, and safe next work.

Release decision remains STOP-SHIP. No business module is approved for hosted production; the app must remain disabled until canonical models, full access controls, Auth/Data API/browser tests, private Storage, and persistence/recovery gates pass.

## Automated completeness-gate interpretation — 2026-10-26

The CI readiness audit intentionally exits successfully while production is disabled; this means it can report blockers without breaking every staging documentation/source commit. It is not a green release verdict. The latest run's log explicitly reported STOP-SHIP for 50 table definitions missing from the five-table schema draft and for all five legacy /api endpoint groups missing. It also reported zero remaining matches in the tracked raw-HTML-sink patterns, which is useful progress but not a substitute for real authorization/runtime testing.

The workflow has no step that runs a real browser against the connected Supabase project, tests Auth/JWT/Data API against the live project, or validates a complete migrated module set. The PostgreSQL tests run in an ephemeral CI service. Therefore do not interpret the successful jobs as proof that the live Proforma, CRM, HR, inventory, finance, payroll, or document flows are operational.

Recommended gate improvement: keep the current disabled-build tests, and later add a separate, explicitly non-production integration workflow with disposable test users/project credentials, real browser automation, and direct company-crossing / role-denial assertions. Do not use production credentials or business records in CI.

## Latest migration-source and auth-bridge progress — 2026-10-26

- Synced the 11 applied migration SQL files available on `main` into secure staging. The four missing historical migration bodies are documented; they have not been fabricated.
- Isolated the incompatible Proforma candidate under `supabase/candidates/` so it cannot be discovered as an executable migration by ordinary Supabase migration tooling.
- The production authentication bridge now derives company/role from active `company_memberships` and the joined live company record, rather than relying on `profiles`. Only explicitly supported membership roles map to full-ERP roles. Company context selection is limited to returned memberships.
- Production role changes remain blocked pending trusted user provisioning and membership management. The full app is still not production-ready: no modules are enabled, no Proforma schema has been applied, and the legacy API/localStorage-dependent modules remain unimplemented.


## General Ledger foundation progress — 2026-10-31

The connected live Supabase project now has 27 public base tables and 23 recorded migrations. Four new company-scoped accounting tables (`ledger_accounts`, `fiscal_periods`, `journal_entries`, `journal_lines`) were applied under migration `20261031113713_add_company_scoped_general_ledger_foundation`. RLS is enabled on all four. A rollback-only authenticated test posted a balanced two-line journal and verified draft-line deletion recalculates totals. No chart of accounts, fiscal periods, or business journals were seeded. This is only the general-ledger foundation; Finance remains disabled pending source-document automation, reversal, bank/tax/close workflows, and browser authorization tests.


## Verified live update — 2026-10-31 (continued)

The connected Supabase project reports **25 applied migration records and 27 public base tables**. Four additional general-ledger tables are present: `ledger_accounts`, `fiscal_periods`, `journal_entries`, and `journal_lines`. The following forward migrations are recorded and source-controlled on `deploy/secure-staging`:
- `20261031113713_add_company_scoped_general_ledger_foundation`
- `20261031114856_add_atomic_journal_posting_and_reversals`
- `20261031115029_fix_reversal_posted_entry_immutability`

The ledger now has authenticated atomic posting and reversal procedures. A rollback-only test exercised both. The first reversal attempt exposed and corrected a trigger-ordering conflict. No production module has been activated and no live business transactions have been created.

The migration source gap is now explicitly counted as seven applied SQL bodies absent from the current repository: the four historical bodies listed above plus the three Proforma/CRM foundation and CRM hardening bodies. The four historical gaps remain benched as requested. The source parity test verifies the 18 available source-controlled applied migrations and documents all seven absent bodies; it does not claim full historical parity.

Finance is still a partial backend foundation, not a complete Finance module. Automated source-document approval checks, integration with AR/AP and inventory, period-close controls, tax/bank/fixed-asset/budget workflows, complete UI bridge and authenticated browser testing remain outstanding. Keep production disabled.


## Latest live migration checkpoint — 2026-10-31 12:50 UTC

- Live Supabase now records **29 applied migrations** and **27 public base tables**. The current source-controlled migration directory tracks **22 available applied SQL bodies**; seven applied bodies remain absent and documented. Four historical bodies remain benched per instruction; three Proforma/CRM foundation bodies require source-control reconciliation.
- CRM now has canonical company-scoped persistence and the V6.7 Sales customer directory, customer form submission, activity timeline, weekly follow-ups and CRM coverage dashboard are wired to the canonical tables. Opportunities and after-sales task APIs exist but dedicated V6.7 controls remain to be built. No authenticated browser test has been completed; keep CRM production activation disabled.
- Supply & Logistics now links inbound shipments to same-company purchase orders and delivery orders to same-company approved/posted sales orders or invoices. The links are optional and preserve existing planning rows. UI source selectors and live browser tests remain pending.
- General Ledger posting and reversal are atomic RPC workflows; direct table writes are restricted to RPCs. No chart of accounts, fiscal periods, or business journals have been seeded.
- Vercel staging builds for commits made while the project exceeded its 100-deployments-per-day free API limit are failing with a plan/rate-limit status. The earlier build assertion failures were caused by the staging entry/source being temporarily out of sync; they have been synchronized again. A new verified deployment cannot be produced until Vercel's rate limit resets or the team changes plan. No paid upgrade was made.
- Production remains disabled, the reviewed module allowlist remains empty, and `main` has not been modified or merged.

- The shipment-to-purchase-order guard was tightened to reject draft, cancelled and void purchase orders, matching the source selector's eligible statuses.
