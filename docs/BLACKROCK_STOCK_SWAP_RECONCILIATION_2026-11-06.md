# BlackRock Historical Stock-Swap Reconciliation — 2026-11-06

## Purpose and scope

This reconciliation separates BlackRock's own inventory and sales from Prime's business records while preserving the stock-only counterparty movements needed to calculate BlackRock's borrowing and repayment balance.

No Prime customer records, sales revenue, supplier balances, payments, or accounting transactions are proposed for import into BOKAN ERP. If approved, only product, date, quantity, unit cost, and counterparty stock movements would be stored in a BlackRock-scoped stock-swap subledger.

## Source reconciliation

Source workbook: `1Q_Report_BR_Prime_Clean_Corporate.xlsx`, `Daily_Data_Entry` sheet.

### BlackRock records

| Source category | Lines | Quantity | Value |
|---|---:|---:|---:|
| Opening Yellow Plywood | 1 | 61 pcs | ETB 262,300 at ETB 4,300/pc |
| BlackRock purchases — Yellow Plywood | 12 | 4,856 pcs | ETB 23,899,500 |
| BlackRock purchases — Green Plywood | 4 | 971 pcs | ETB 4,855,000 |
| **BlackRock purchases total** | **16** | **5,827 pcs** | **ETB 28,754,500** |
| BlackRock sales — Yellow Plywood | 25 | 4,517 pcs | Selling prices blank |
| BlackRock sales — Green Plywood | 2 | 642 pcs | Selling prices blank |
| BlackRock sales — Morale Timber | 2 | 450 pcs | Selling prices blank |
| **BlackRock sales total** | **29** | **5,609 pcs** | **Selling prices blank** |

The 16 BlackRock purchase lines and ETB 28,754,500 total match the live database's 16 purchase documents and aggregate value. The live database currently has 31 sales lines totalling 5,929 pcs, which is 2 lines / 320 pcs above the workbook. The additional lines are a 20-piece Yellow Plywood sale and a 300-piece Morale Timber sale dated 2026-09-24, recorded under Argaw Kettalew; they are not present in the workbook and must be reconciled, not deleted automatically.

### Prime stock-only counterparty movements in the workbook

| Product | Prime purchases | Prime sales |
|---|---:|---:|
| Yellow Plywood | 2,501 pcs | 1,923 pcs |
| Green Plywood | 1,029 pcs | 806 pcs |
| Morale Timber | 900 pcs | 296 pcs |

These quantities are not Prime ERP financial records. They are listed here because the workbook's stock-swap logic uses Prime's stock as the counterparty pool from which BlackRock may borrow, and to which BlackRock purchases first repay outstanding quantities.

## Required stock-swap rules

1. Start BlackRock with its own opening quantity: 61 Yellow Plywood pieces on 2026-07-01.
2. Record Prime stock receipts as counterparty stock-pool movements, not as BlackRock purchases.
3. For each BlackRock sale, issue BlackRock-owned stock first. Any shortfall is a borrow from the Prime counterparty pool and increases BlackRock's owed quantity.
4. For each BlackRock purchase, repay the outstanding Prime quantity first. Only the remaining quantity increases BlackRock-owned stock.
5. Prime sales reduce the counterparty pool; they do not become BlackRock sales.
6. Keep quantity, cost, and ownership balances visible by product and date. Do not import Prime customer names, revenue, supplier payments, or general-ledger records.
7. Use the workbook's running weighted-average cost method only after the complete product-level receipt/issue chronology and the opening-stock exceptions are reconciled.

## Historical exceptions requiring reconciliation

- **Green Plywood:** BlackRock recorded a 242-piece sale on 2026-09-24, before the first recorded Green Plywood purchase by either company on 2026-09-29. There is no recorded Green opening balance. This sale has no supported stock source in the workbook chronology.
- **Morale Timber:** BlackRock recorded a 300-piece sale on 2026-07-11, before the first recorded Morale Timber purchase (900 pieces by Prime on 2026-09-01). The workbook itself notes: “Sale made before 11-Jul; stock not in opening balance.” This needs a documented opening quantity/source or an explicit decision to retain it as a historical exception without stock/COGS posting.
- **Yellow Plywood:** The stock-swap chronology produces negative Prime counterparty stock at several October events; the deepest recorded deficit is 211 pieces on 2026-10-18 before later movements restore the balance. The chronology must be reconciled against physical stock and missing/delayed source movements before it is used to authorize stock issues.
- **Sales prices:** The historical sales rows have blank unit selling prices. Revenue and gross profit must remain incomplete until prices are entered; no estimated revenue should be posted.

## Live ERP state and release treatment

- Live sales documents: 28 drafts; 31 lines; 5,929 pcs; no posted sales stock movements.
- Live purchase documents: 16 drafts; 5,827 pcs; ETB 28,754,500; no posted purchase receipts.
- Live stock movements: zero.
- The purchase-receiving workflow and opening-stock seed exist only as isolated candidate SQL and have passed disposable PostgreSQL tests. Neither has been applied to live Supabase.
- Historical sales and purchase documents remain drafts until the 320-piece sales difference, missing selling prices, and stock-swap exceptions are reconciled.

## Implementation recommendation

Implement a BlackRock-scoped stock-swap subledger with a named external counterparty (“Prime Investment Group”) and stock-only movement records. Keep it separate from Prime company membership and accounting records. The ledger should expose borrowed quantity, repayments, owed balance, counterparty availability, and audit notes by product/date. Enforce available counterparty stock on new borrow events; historical negative-stock events should be retained as exceptions, not silently normalized.
