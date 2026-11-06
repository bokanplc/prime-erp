# BlackRock historical sales and purchasing reconciliation — 2026-11-06

## Source reviewed

Library workbook: `1Q_Report_BR_Prime_Clean_Corporate.xlsx`, sheet
`Daily_Data_Entry`. The source register contains 90 populated transaction rows
across BlackRock and the former PRME entity. This reconciliation deliberately
counts **BlackR / BlackRock only**; PRME rows are excluded under the current
single-company scope.

## BlackRock source register totals

| Transaction type | Lines | Quantity | Recorded value |
|---|---:|---:|---:|
| Opening stock | 1 | 61 pcs | ETB 262,300 at recorded unit cost |
| Purchases | 16 | 5,827 pcs | ETB 28,754,500 |
| Sales | 29 | 5,609 pcs | Not priced in the source register |

Purchase split:
- Yellow Plywood: 12 lines, 4,856 pcs, ETB 23,899,500.
- Green Plywood: 4 lines, 971 pcs, ETB 4,855,000.

Sales split:
- Yellow Plywood: 25 lines, 4,517 pcs.
- Green Plywood: 2 lines, 642 pcs.
- Morale Timber: 2 lines, 450 pcs.

The source register has no sales unit prices for these 29 BlackRock sales lines.
Those prices must remain blank / incomplete until supplied; do not invent revenue.

## Live Supabase comparison

Read-only audit of project `kafiwnuynjemufnankvi` found:

| Area | Live records | Finding |
|---|---:|---|
| Sales documents | 28 | All draft |
| Sales document items | 31 | 5,929 pcs; all line totals ETB 0 |
| Purchase documents | 16 | All draft |
| Purchase document items | 16 | 5,827 pcs; ETB 28,754,500 |
| Suppliers | 0 | All 16 purchase documents have NULL supplier_id |
| Stock movements | 0 | No receipt / issue movements posted |
| Stock ledger | 0 | Opening stock not posted |
| Products | 3 | Historical document lines use descriptions; product_id linkage requires review |

Purchasing quantities and values reconcile exactly to the BlackRock source register.
However, no purchase is supplier-linked or posted/received, so this is not yet an
operational inventory balance.

Sales differ from the current source register by **two extra database lines,
totalling 320 pcs**: Yellow Plywood 20 pcs and Morale Timber 300 pcs for
Argaw Kettalew on 2026-09-24. These lines are present in the live database but
not in the currently reviewed workbook. They must be traced to their original
source before being retained or removed. Do not delete them automatically.

The live database has 31 sales lines / 5,929 pcs compared with 29 source lines /
5,609 pcs. The 28 document count is consistent with grouped multi-product
sales, but the extra two lines remain an unresolved source discrepancy.

## Additional date-quality issue

Two live historical sales documents currently carry the placeholder date
`2025-01-01`. One is the Assosa 40-pc Yellow Plywood line, whose current source
register shows 2026-09-19; the other is the prior Ewket Hailu 300-pc Morale Timber
line, which is flagged in the workbook as having occurred before 2026-07-11 and
therefore may legitimately need an estimated placeholder. Confirm the Assosa
date against the source and correct it through a controlled data migration; do
not assume the placeholder is correct.

## Required follow-up before inventory / financial release

1. Trace the two extra Argaw Kettalew lines to the authoritative original source.
2. Correct the Assosa date if the workbook date is confirmed.
3. Preserve the 300-pc prior Ewket sale as a flagged estimated-date record unless
   a reliable exact date is recovered.
4. Create/link the 16 historical purchase suppliers from the source names.
5. Link the 16 purchase lines and the 29 confirmed sales lines to the three
   canonical product records, where product identity matches.
6. Record the 61-pc BlackRock Yellow Plywood opening stock using a documented
   opening-stock movement, without inventing a stock receipt from the old PRME
   company.
7. Complete stock receipt / issue workflow tests and verify the resulting
   on-hand balance chronologically.
8. Keep all historical sales/purchase documents as drafts until the source
   reconciliation and approval rules are complete. Do not create customer
   receipts or supplier payments in this ERP; those remain in Peachtree.

## Scope / safety

This is an audit record only. No business transactions, dates, supplier links,
product links, document statuses, stock balances, or historical records were
changed by this reconciliation. Former PRME rows are not imported into the
BlackRock company.
