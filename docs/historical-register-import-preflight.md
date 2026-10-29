# BOKAN ERP historical sales and purchase import — preflight

Status: **PREPARATION ONLY — no live records inserted**

Source workbook: `Quarterl Report BR Prime Final.xlsx`
Use the itemized `Consolidated Purchase Report` and `Consolidated Sales Report` registers as the transaction source. Do not use the static `Executive Summary` as a transaction source.

## Source totals to reconcile

| Register | PRME | BlackR | Combined |
|---|---:|---:|---:|
| Purchases, all product lines | 4,430 | 5,152 | 9,582 |
| Sales, all product lines | 2,619 | 5,051 | 7,670 |

Purchase product totals: yellow plywood 6,682; green plywood 2,000; morale timber 900.
Sales product totals: yellow plywood 5,316; green plywood 1,308; morale timber 1,046.

The printed/static sales summary says 6,770, which is 900 below the itemized register total (yellow +540, green +360; morale matches). Preserve both figures in the audit trail; do not silently overwrite the itemized rows.

## Hard blockers before posting

1. Sales source row 27 is column-shifted / date-missing; its quantity and product interpretation must be confirmed.
2. Sales source row 29 is marked “Before Jul 11” for 300 morale timber pieces; exact transaction date is unknown.
3. Purchase source row 27 has a 2026-10-26 date cell but says “Delivered Oct 27”.
4. Purchase source row 28 has a 2026-10-27 date cell but says “Delivered Oct 28”.
5. The workbook does not contain sale prices, purchase unit costs, invoice totals, or payment details. Do not invent financial values. Documents with zero-value defaults must not be presented as complete accounting records.
6. Customer and supplier names need verified master-data mapping before foreign keys are assigned. Do not create duplicate parties from spelling variants without review.
7. Intercompany stock ownership must be reconciled separately from company stock movements.

## Known opening and ownership facts

- BlackRock opening balance on 2026-07-01: 61 yellow plywood pieces.
- Prime purchased 1,200 yellow plywood pieces on 2026-07-08 (two 600-piece purchase-register rows). **These are purchases, not a separate opening balance; do not count them twice.**
- BlackRock's first 120-piece yellow plywood sale on 2026-07-11 was explicitly supplied from Prime stock. Keep that stock in Prime's ledger and record the corresponding quantity BlackRock owes Prime.
- Later BlackRock manufacturer purchases should first reduce this known intercompany obligation; only excess should be treated as BlackRock-owned stock. Do not apply this assumption to other BlackRock sales without evidence.

## Database compatibility findings

The live Supabase schema has company-scoped products, customers, suppliers, sales/purchase documents, line items, and stock movements. Product, customer, and supplier master data were previously observed empty, so IDs cannot be safely mapped by name until verified or created intentionally.

Current stock movement types do not include a dedicated intercompany loan/return movement. Do not represent borrowed stock as an ordinary BlackRock-owned purchase or silently change company balances. A properly auditable intercompany stock ledger/transfer model is needed before posting this history.

## Safe execution sequence

1. Parse and retain source row IDs for idempotency.
2. Resolve the four date/alignment blockers above.
3. Map or intentionally create company-specific products and third parties.
4. Build a chronological stock ledger, including explicit intercompany obligation quantities.
5. Validate negative-stock conditions and reconcile quantities by company/product.
6. Test in an isolated database or transaction that is rolled back; verify repeated runs do not duplicate records.
7. Only after all validations pass, prepare a production import plan and request explicit approval before inserting historical records into live Supabase.

No production migration, production write, or deployment is authorized by this preflight document.
