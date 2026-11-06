# BOKAN ERP V6.7 — Live migration checkpoint

**Checkpoint:** 2026-11-06 UTC  
**Working branch:** `deploy/secure-staging`  
**Scope:** BlackRock Investment PLC only  
**Release posture:** STOP-SHIP — staging review only; do not merge to `main` or enable production mode.

## Verified source and deployment

- The full V6.7 staging artifact contains **90 tab panels**. The preserved source file and `staging/index.html` are byte-for-byte synchronized.
- A static parse check passed for all **36 inline JavaScript blocks**; no syntax errors were found.
- Latest Vercel preview deployment is **READY** from `deploy/secure-staging`. The build log identifies it as a staging-only demo-review artifact with sample data and no Supabase credentials. It is not a live-data ERP release.
- `PRODUCTION_MODE`, `FULL_ERP_DATA_READY`, and the reviewed production-tab allowlist remain disabled. `main` has not been changed or promoted.

## Verified live Supabase foundation

- **46 public base tables**; RLS is enabled on all 46; zero public base tables are missing RLS.
- **36 applied migrations**, including the two 2026-11-06 forward migrations recorded below.
- The company registry contains only active **BLACKROCK / BlackRock Investment PLC**. Prime has been decommissioned from the target project.
- Current company membership inventory has only the existing administrator membership. Sales and data-entry staff memberships have not yet been provisioned.
- 55 previously uncovered foreign keys now have covering indexes. The performance advisor no longer reports unindexed foreign keys or duplicate permissive SELECT policies on the two Finance tables.
- Remaining advisor observations: three authenticated-only SECURITY DEFINER RPC warnings (CRM reassignment and Finance journal post/reverse), the Auth leaked-password-protection setting warning, and unused-index informational notices. No business behavior was changed by the index/RLS-performance migrations.

### New forward migrations

- `20261106062819_index_uncovered_foreign_keys` — additive indexes for the previously uncovered public-schema foreign keys.
- `20261106062902_split_finance_read_and_write_rls_policies` — separates Finance write policies from member read policies while preserving the existing owner/admin/manager/accountant write conditions.

Both migration SQL files are source-controlled under `supabase/migrations/` and recorded in the live migration history.

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
| CRM | Live CRM tables and bridge exist; target actuals now use company-scoped `crm_activities` in production instead of nonexistent `customer_logs` | No activities/opportunities/after-sales tasks yet; salesperson visits/calls/reminders and team performance tests |
| Sales operations | `sales_targets`, `trip_plans`, `visit_reports`, and per-diem schema are present | No migrated targets/trips/visits; commission logic and staff ownership must be reconciled before activation |
| Supply & Logistics | Company-scoped inbound shipment and delivery-control tables plus bridge exist | No live records; sales-demand, reservations, receiving/stock posting and exceptions remain |
| Finance | GL tables and atomic `post_journal_entry` / reversal RPCs exist; Finance adapter now uses live table names and company UUID | No chart-of-accounts seed, fiscal periods, or journals; approved-source posting/idempotency, bank/tax/budget/fixed-assets/close and browser tests |
| HR / Payroll | HR tables and UUID-scoped bridge exist | No employee/payroll rows; employee self-service, sensitive payroll separation, approvals and browser role tests |
| Inventory | Products and stock movement foundation exist | No stock movements; opening balances and all historical stock sources must be reconciled before posting |
| Documents / storage | Metadata table exists | Private Storage buckets, object policies and signed downloads not implemented |
| Remaining V6.7 modules | All 90 UI panels remain in the full review artifact | Each module still needs a source-to-schema map, persistence, trusted writes, RLS and browser acceptance tests |

## Recent source changes

- Finance adapter aligned to `journal_entries`, `fiscal_periods`, `ledger_accounts`, `sales_documents`, and `purchase_documents`; company UUID is resolved before queries; journal posting calls the atomic RPC. No receipt/payment write methods are exposed.
- HR adapter resolves the active company UUID and includes it in inserts.
- Sales target actuals use `crm_activities` and company-scoped `profiles` in production; the legacy `customer_logs` path remains only for demo review mode.
- Finance/HR audit and BlackRock-only workplan have been updated to match the live schema and current project scope.

## Next work sequence

1. Reconcile the opening-stock source without reintroducing Prime as a company or importing Prime-owned transactions.
2. Complete real authenticated browser tests for the CRM and Supply & Logistics slices.
3. Continue the remaining V6.7 module-by-module persistence and trusted-write migration, prioritizing customer lifecycle, stock, sales operations, expenses and documents.
4. Finish Finance source-document automation and HR sensitive-data/approval controls.
5. Provision staff memberships only when the employees' authenticated accounts are ready.
6. Keep the production allowlist empty and do not promote `main` until the full ERP passes its acceptance gates.
