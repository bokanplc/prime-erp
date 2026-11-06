# BOKAN ERP V6.7 — Live migration checkpoint

**Checkpoint:** 2026-11-06 UTC  
**Working branch:** `deploy/secure-staging`  
**Scope:** BlackRock Investment PLC only  
**Release posture:** STOP-SHIP — staging review only; do not merge to `main` or enable production mode.

## Verified source and deployment

- The full V6.7 staging artifact contains **91 tab panels**. The preserved source file and `staging/index.html` are byte-for-byte synchronized. All **40 inline JavaScript blocks** pass static syntax parsing.
- Latest Vercel preview deployment is **READY** from `deploy/secure-staging` at `https://prime-2rf3ih35e-bokanplc-3642.vercel.app`. The build log identifies it as a staging-only demo-review artifact with sample data and no Supabase credentials. It is not a live-data ERP release.
- `PRODUCTION_MODE`, `FULL_ERP_DATA_READY`, and the reviewed production-tab allowlist remain disabled. `main` has not been changed or promoted.

## Verified live Supabase foundation

- **48 public base tables**; RLS is enabled on all 48; zero public base tables are missing RLS.
- **40 applied migrations (rechecked against the live migration history on 2026-11-06)**, including the seven 2026-11-06 forward migrations recorded below.
- The company registry contains only active **BLACKROCK / BlackRock Investment PLC**. The full V6.7 UI and demo-review data are now single-company: no Prime company option, company context, or Prime sample transactions remain. The context selector is locked to BlackRock.
- Current company membership inventory has only the existing administrator membership. Sales and data-entry staff memberships have not yet been provisioned.
- 55 previously uncovered foreign keys now have covering indexes. The performance advisor no longer reports unindexed foreign keys or duplicate permissive SELECT policies on the two Finance tables. The supply-shipment purchasing-entity constraint now accepts only BlackRock and BOKAN Coordinated.
- Remaining advisor observations: three authenticated-only SECURITY DEFINER RPC warnings (CRM reassignment and Finance journal post/reverse), the Auth leaked-password-protection setting warning, and unused-index informational notices. No business behavior was changed by the index/RLS-performance migrations.

### New forward migrations

- `20261106062819_index_uncovered_foreign_keys` — additive indexes for the previously uncovered public-schema foreign keys.
- `20261106062902_split_finance_read_and_write_rls_policies` — separates Finance write policies from member read policies while preserving the existing owner/admin/manager/accountant write conditions.
- `20261106063435_decommission_prime_purchasing_entity` — removes the decommissioned Prime purchasing-entity value from the live supply-shipment constraint.
- `20261106064054_create_transaction_costs_for_direct_and_landed_costs` — adds the company-scoped register for landed costs, direct sales costs and operating expenses, with member-create / finance-manage RLS.
- `20261106064214_index_transaction_costs_creator_membership_fk` — adds the composite index for the new creator-membership foreign key.
- `20261106064931_create_company_policy_documents` — adds a member-readable, admin-managed policy document table with RLS.
- `20261106065301_index_company_policy_documents_creator_membership_fk` — indexes the policy document creator-membership foreign key.

All seven migration SQL files are source-controlled under `supabase/migrations/` and recorded in the live migration history.

## Historical BlackRock transaction migration

Source workbook: `1Q_Report_BR_Prime_Clean_Corporate.xlsx`, `Daily_Data_Entry` sheet.

- The workbook contains 46 BlackRock rows: 1 opening-stock row, 29 sales lines, and 16 purchase lines. Prime-tagged rows were excluded.
- All 29 BlackRock sales lines (5,609 pcs) are now represented in the sales documents. Three missing draft invoices were added: Matusala 150 pcs (2026-07-24), Ortid 593 pcs (2026-10-28), and Ortid 135 pcs (2026-10-29).
- Two pre-existing Argaw line items (320 pcs total) were retained although they are not in the current workbook. Current database sales inventory is 28 documents / 31 lines / 5,929 pcs, including those two legacy lines.
- All 16 BlackRock purchase lines (5,827 pcs) are represented. Fifteen existing purchase line costs were updated to the workbook's actual ETB 4,500 / 5,000 values and document totals recalculated; the two latest delivery dates were aligned to 2026-10-27 and 2026-10-28; the 675-piece 2026-11-02 purchase was added.
- Reconciled purchase value: **ETB 28,754,500**.
- Sales unit prices were blank in the source and remain ETB 0 pending later price entry. No sales revenue was invented.
- Sales and purchase documents remain drafts. No receipts, supplier payments, journal postings, stock issues, or purchase receipts were created. Customer receipts and supplier payments remain in Peachtree.

The 61-piece Yellow Plywood opening-stock row is not posted to inventory. The source's July 8 purchase of 1,200 pieces is Prime-tagged and outside the BlackRock-only scope, while Morale Timber sales lack a matching BlackRock opening/purchase quantity. The live `stock_movements` table remains empty until the opening stock and source-of-stock reconciliation is resolved.

## Module-by-module position

| Area | Current position | Remaining acceptance work |
|---|---|---|
| Identity / company context | Supabase Auth bridge derives access from active company memberships; only BlackRock remains | Add sales/data-entry memberships; real sign-in, session, company and role-denial browser tests |
| Customers / sales documents | 22 BlackRock customers; 28 sales docs / 31 lines; historical sales and purchases loaded as drafts | Fill missing sale prices; approvals, stock posting, customer assignment and end-to-end document lifecycle |
| CRM | Full company-scoped CRM workspace includes customer master, call/visit/activity logging, pipeline opportunities, after-sales reminders, customer history, reassignment and representative coverage; target actuals use company-scoped `crm_activities` | No CRM activities/opportunities/tasks yet; staff memberships and real Auth/RLS browser tests remain |
| Sales operations | `sales_targets`, `trip_plans`, `visit_reports`, and per-diem schema are present | No migrated targets/trips/visits; commission logic and staff ownership must be reconciled before activation |
| Supply & Logistics | Company-scoped inbound shipment and delivery-control tables plus bridge exist | No live records; sales-demand, reservations, receiving/stock posting and exceptions remain |
| Finance | GL tables and atomic `post_journal_entry` / reversal RPCs exist; Finance adapter now uses live table names and company UUID | No chart-of-accounts seed, fiscal periods, or journals; approved-source posting/idempotency, bank/tax/budget/fixed-assets/close and browser tests |
| HR / Payroll | HR tables and UUID-scoped bridge exist | No employee/payroll rows; employee self-service, sensitive payroll separation, approvals and browser role tests |
| Inventory | Products and stock movement foundation exist | No stock movements; opening balances and all historical stock sources must be reconciled before posting |
| Transaction costs / profitability | New `transaction_costs` table and UI classify landed costs, direct sales costs and operating expenses; management reporting calculates landed gross profit and profit after direct sales costs from posted invoices and fully costed stock issues | No real cost rows yet; profit metrics correctly remain pending until posted sales and stock issue movements exist |
| Company policy handbook | RLS-protected `company_policy_documents` contains one active handbook; the employee viewer is read-only, visible to all employee roles, and offers print only to admins | Authenticated production access is still disabled; non-admin print is suppressed in the app, but screenshots/copy cannot be technically prevented |
| Documents / storage | Metadata table exists | Private Storage buckets, object policies and signed downloads not implemented |
| Remaining V6.7 modules | All 91 UI panels remain in the full review artifact | Each module still needs a source-to-schema map, persistence, trusted writes, RLS and browser acceptance tests |

## Recent source changes

- Finance adapter aligned to `journal_entries`, `fiscal_periods`, `ledger_accounts`, `sales_documents`, and `purchase_documents`; company UUID is resolved before queries; journal posting calls the atomic RPC. No receipt/payment write methods are exposed.
- HR adapter resolves the active company UUID and includes it in inserts.
- Sales target actuals use `crm_activities` and company-scoped `profiles` in production; the legacy `customer_logs` path remains only for demo review mode.
- A full CRM workspace UI is now wired to the existing CRM production adapter: customer create/edit, activity/call/visit logging, pipeline creation/stage updates, after-sales tasks, customer history, and customer reassignment. All forms remain disabled in demo-review mode and require the authenticated company context.
- The Expense Ledger now includes a separate Transaction Cost Register for factory selection, quality assistance, dealer referral, loading, transport and other costs. Entries are classified as landed cost, direct sales cost or operating expense; customer receipts and supplier payments are not recorded.
- The supplied Company Policy Handbook is stored in a company-scoped, RLS-protected table and exposed through a read-only employee viewer. All employee roles receive the tab; only administrators receive the print control. The viewer uses cleaned HTML text, not a downloadable PDF.
- Management Reporting now shows landed gross profit and profit after direct sales costs. It excludes drafts and remains pending until posted sales invoices and fully costed stock issues are available.
- Finance/HR audit and BlackRock-only workplan have been updated to match the live schema and current project scope.

## Next work sequence

1. Reconcile the opening-stock source without reintroducing Prime as a company or importing Prime-owned transactions.
2. Complete real authenticated browser tests for the CRM and Supply & Logistics slices.
3. Continue the remaining V6.7 module-by-module persistence and trusted-write migration, prioritizing customer lifecycle, stock, sales operations, expenses and documents.
4. Finish Finance source-document automation and HR sensitive-data/approval controls.
5. Provision staff memberships only when the employees' authenticated accounts are ready.
6. Keep the production allowlist empty and do not promote `main` until the full ERP passes its acceptance gates.


### Hosted sign-in and employee access gate

The Supabase Auth Google identity is linked to the existing active BlackRock administrator account and its company membership. The full V6.7 login now includes a Google OAuth button/handler alongside email/password and supports an explicit `AUTH_REDIRECT_URL` override (blank uses the current origin). This cannot be end-to-end tested while `PRODUCTION_MODE=false`, the Supabase browser URL/key are blank, and the current preview origin may not be in Supabase's redirect allowlist.

Vercel project protection is currently enabled for all non-custom domains, and the project has only Vercel-hosted domains attached. Keep staging protected. Before employee release, attach the intended custom company domain (or make an explicit access-protection decision), add that exact domain to Supabase Auth's allowed redirect URLs, and test the Google callback with the existing linked admin identity plus employee memberships.


## Follow-through audit — 2026-11-06 (live recheck)

A fresh read-only check was run against the connected Supabase project while continuing the remaining migration work:

- Public base tables: **48**.
- RLS-enabled public base tables: **48**; tables without RLS: **0**.
- Applied migration records: **40** (the previous 41 count in this document was inaccurate and is corrected above).
- Company registry: **1** active BlackRock company.
- Company memberships: **1** active administrator membership. The Auth project contains three user accounts, but only one is attached to the company; do not grant roles to the other accounts until their intended employee identities and roles are confirmed.
- RLS policy inventory: all 48 tables have RLS enabled; policy counts vary by table and must still be tested with real authenticated sessions.
- Security advisor: three authenticated-callable SECURITY DEFINER RPC warnings remain for customer reassignment and journal post/reversal. The function bodies currently include explicit `auth.uid()`, company-membership/role checks, and restricted search paths; do not remove SECURITY DEFINER blindly because the atomic RPCs require controlled privileged writes. Continue reviewing their EXECUTE grants and role-denial tests.
- Auth advisor: leaked-password protection is disabled and requires an owner-level Supabase Auth setting change.
- Performance advisor: 91 unused-index informational observations are expected on a lightly used staging database; no index was dropped.

### Remaining work is now split into actionable and owner-dependent items

**Can be completed in code/database without owner input:** finish source-to-live field mapping for every remaining V6.7 tab; connect legacy forms to canonical company-scoped tables; implement missing trusted workflows and constraints; migrate documents to private Storage; add automated static/schema tests; and expand disposable-user Auth/RLS integration tests.

**Requires owner-controlled information or settings:** employee account-to-role mapping and memberships; exact opening stock/financial balances and the source documents that support them; approval of any uncertain historical stock ownership; the intended company login domain / redirect allowlist; and enabling leaked-password protection in Supabase Auth.

### Private document repository migration — 2026-11-06

- Applied migration `20261106075213_create_private_company_document_storage`; live migration history now records **40** applied migrations.
- Created private bucket `bokan-company-documents` with a 25 MB upload limit and an explicit allowlist for PDF, common image, text, Word, Excel and PowerPoint formats.
- Storage RLS permits active company members to read and upload only beneath their own company UUID folder. Only owner/admin/manager members may update or delete objects.
- Updated the full V6.7 Document Repository upload/list/delete flow to use the private bucket, company-scoped metadata rows, short-lived signed download URLs (5 minutes), and manager-only delete controls. Preview mode retains its existing isolated demo storage behavior.
- Updated both staging HTML entry/source files and statically parsed all 40 inline JavaScript blocks with zero syntax errors. The two files remain byte-identical.
- Vercel created a **READY** staging preview for the synchronized entry-point commit `e9bd119`; the intermediate source-only deployment errored while the two files were temporarily out of sync. The READY deployment uses the synchronized commit.

No production setting, production allowlist, or `main` branch change was made by this audit.
