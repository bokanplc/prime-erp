# V7 commercial calculation rules

These calculations support commercial quotations and profitability reporting only. They are not accounting postings and do not record customer receipts, supplier payments, bank movements, stock movements or inventory balances.

## VAT

- Default VAT rate: 15% (1,500 basis points).
- Each amount explicitly states whether it is VAT-exclusive, VAT-inclusive or not subject to VAT.
- VAT-inclusive amounts are split into net value and VAT using integer cents and rounding.
- Recoverable input VAT is excluded from the commercial cost only when the source record is explicitly marked recoverable. Non-recoverable VAT remains part of the cost.
- VAT treatment must be selected from the source document; the application must not infer recoverability from the supplier or transaction type alone.

## Profitability

- Revenue is measured excluding output VAT.
- Landed purchase cost is the supplied transaction-level landed cost, normalized according to its VAT treatment and recoverability.
- Landed gross profit = revenue excluding VAT − landed purchase cost.
- Direct transaction costs include transportation, loading and miscellaneous unexpected purchase/sales costs.
- Profit after direct costs = landed gross profit − direct transaction costs.
- Margin percentages use revenue excluding VAT as the denominator. A zero-revenue result has no percentage margin.

## Scope guardrails

- No stock quantity, inventory valuation or inventory costing is derived by this calculation module.
- No general ledger, journal, accounts receivable/payable, bank reconciliation or payment processing is created.
- No customer receipt or supplier payment functionality is included; payments remain in Peachtree.
- Commercial calculations are recomputed from transaction inputs; they do not alter historical records silently.
- Production use requires the source documents and VAT treatment fields to be verified during implementation and acceptance.
