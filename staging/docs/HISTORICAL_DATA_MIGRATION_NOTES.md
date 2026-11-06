# BOKAN ERP V6.7 — Historical transaction migration notes

Updated: 2026-11-05  
Target company: **BlackRock Investment PLC** only  
Source workbook: `1Q_Report_BR_Prime_Clean_Corporate.xlsx`, `Daily_Data_Entry` sheet

## Imported and reconciled

- The source sheet contains 46 BlackRock rows: 1 opening-stock row, 29 sales lines, and 16 purchase lines. Prime-tagged rows were excluded in accordance with the BlackRock-only project scope.
- All 16 BlackRock purchase lines are now represented in `purchase_documents` / `purchase_document_items`.
  - The 15 existing purchase lines were updated from the workbook's actual unit costs (ETB 4,500 / 5,000) and their document totals recalculated.
  - The two delivery dates previously offset by one day were aligned to the latest workbook: the 550-piece delivery is dated 2026-10-27 and the 600-piece delivery is dated 2026-10-28.
  - The 675-piece purchase dated 2026-11-02 was added as a draft supplier invoice.
  - Reconciled purchase quantity: **5,827 pcs**. Reconciled purchase value: **ETB 28,754,500**.
- The 29 BlackRock sales lines in the workbook (5,609 pcs) are now represented in the sales documents. The database also retains two pre-existing Argaw line items (320 pcs total) that are not present in the current workbook. Three missing lines were added as draft invoices: Matusala 150 pcs (2026-07-24), Ortid 593 pcs (2026-10-28), and Ortid 135 pcs (2026-10-29).
- Two additional Argaw line items already present in the database were retained; they are not in the current workbook's Daily_Data_Entry list and were not deleted.
- Sales prices were blank in the source workbook. Those lines remain at ETB 0 pending later price entry; no revenue has been fabricated.

## Posting and accounting boundary

- Historical sales and purchase documents remain **draft**. No sales stock issue, purchase receipt, journal posting, customer receipt, or supplier payment was created by this import.
- Customer receipts and supplier payments remain in Peachtree, per the project decision.
- The workbook's 61-piece Yellow Plywood opening-stock row has not been posted to inventory. The source also contains a July 8 Prime purchase of 1,200 pieces that is outside the current BlackRock-only scope, and the Morale Timber sales do not have a matching BlackRock opening/purchase quantity. Posting stock before those opening-balance questions are reconciled would create a misleading on-hand balance.
- The stock-movement table remains untouched; inventory posting is a separate controlled step after opening quantities are reconciled.

## Production adapter corrections in this branch

- The V6.7 Finance adapter now targets the live schema names (`journal_entries`, `sales_documents`, `purchase_documents`, `fiscal_periods`, and `ledger_accounts)) and resolves the active company's UUID before querying.
- Journal posting now uses the existing atomic `post_journal_entry` RPC, which validates balanced debit/credit lines, active accounts, open fiscal period, and company membership.
- The Finance adapter intentionally exposes no customer-receipt or supplier-payment write methods.
- The V6.7 HR adapter now resolves the active company's UUID and includes it in inserts, matching the live schema and RLS policies.
- The full staging source and `staging/index.html` remain synchronized. The latest Vercel preview build for `deploy/secure-staging` completed successfully. It remains a demo-review deployment, not production access.

## Remaining work

1. Reconcile opening stock and the historical July stock source without reintroducing Prime as a company or importing Prime-owned transactions.
2. Complete controlled inventory posting after opening quantities are agreed.
3. Continue module-by-module schema, company-scope, persistence, RLS, and browser workflow verification before approving any production tabs.
4. Keep production mode disabled and do not promote `main` until the full V6.7 application is genuinely ready.
