# BlackRock V6.7 — Confirmed Operational Scope

**Decision status:** Owner-confirmed on 2026-11-03.  
**Application:** Existing full BOKAN ERP V6.7 migration, BlackRock Investment PLC only.  
**Implementation rule:** Continue the existing `feature/blackrock-only-v67` → `deploy/secure-staging` work. Do not restart, rebuild a reduced app, alter `main`, merge the draft PR, or enable production mode until release gates pass.

## 1. Product direction

Build a **full CRM with the operational ERP controls needed to run BlackRock's trading business**. This is not intended to replace Peachtree or become a full accounting package.

Peachtree remains the accountant's formal accounting system. The ERP should provide management-grade customer, sales, procurement, stock, cost and gross-margin information without duplicating formal bookkeeping.

## 2. Full CRM — in scope

- Customer and prospect master records, contacts, locations and segmentation.
- Leads and sales opportunities with configurable pipeline stages.
- Customer ownership and salesperson assignment.
- Call, visit, meeting, quotation and other activity history.
- Follow-up dates, reminders, next actions and overdue-task views.
- Customer purchase history and product preferences.
- After-sales service, complaints, returns coordination and retention tasks.
- Salesperson targets, activity and conversion reporting.
- Sales performance, commission calculation and manager eligibility rules already defined by the owner.
- Customer and salesperson dashboards.

Customer history is operational and sales-focused. Do not create a customer receipt ledger or payment collection workflow.

## 3. Operational ERP — in scope

### Sales and pricing
- Quotations, proformas, sales orders, invoices and delivery records where present in V6.7.
- Product-level sales prices, price history and authorized price changes.
- Salesperson/customer/product/period sales analysis.
- Returns and adjustments with stock effects and audit history.

### Purchasing and supplier operations
- Supplier and factory records.
- Purchase requests/orders, purchase documents, goods receiving and purchase history.
- Purchase price by product, supplier, shipment and date.
- Supplier/product price comparison.
- Purchase returns and receiving discrepancies.

### Inventory and stock control
- Opening stock, stock on hand, stock movements and location balances.
- Receipts, issues, transfers, adjustments and returns.
- Stock borrowing, lending, swaps, replenishment and outstanding quantities.
- Chronological stock history and traceability.
- Stock valuation using a documented costing method; do not infer stock balances from draft documents.
- Reorder and slow-moving stock reports.

### Direct operational cost capture and profitability
Record the full cost of sourcing, acquiring, handling and delivering merchandise. Capture both expected and unexpected costs, including:
- Factory selection assistance and product sorting/quality-check fees.
- Documented sourcing, introduction or dealer referral fees.
- Inbound transportation, loading, unloading and handling.
- Documented road, travel, access, permit or route-related charges.
- Storage, packaging, inspection, delivery and other directly attributable costs.
- Other incidental business costs, with an explanation rather than an unexplained catch-all.

Each cost record should capture date, amount, currency, category, recipient/payee where known, purpose/description, who recorded it, supporting evidence where available, and a transparent compliance/review note where the nature of the payment requires review.

Link a cost to the most specific available purchase, shipment, supplier, product, sales order, delivery or customer. Permit an unallocated cost to be recorded immediately and assigned later. Preserve the original cost record and an audit trail of allocations and corrections.

Use separate cost phases:
- **Procurement / inbound:** included in landed product cost.
- **Sales / outbound fulfilment:** deducted after landed gross profit to calculate direct contribution.
- **Unallocated / review:** excluded from final product/order profitability until assigned or deliberately classified as non-allocable.

Provide configurable allocation by quantity, weight, volume or purchase value, with a recorded method and allocation basis. Avoid double-counting an expense across purchase, shipment and delivery records.

### Required profitability views
1. Merchandise gross profit = sales revenue less merchandise purchase cost.
2. Landed gross profit = sales revenue less merchandise cost and allocated procurement/inbound costs.
3. Direct contribution = landed gross profit less allocated direct sales/outbound costs.

Show both amount and margin percentage by product, purchase batch, sales document, customer, salesperson and reporting period where source data supports the calculation. Clearly identify estimates, unallocated costs and missing cost inputs.

## 4. Explicitly out of scope — do not build or enable as operational workflows

- General ledger, chart of accounts, journal posting and reversals.
- Trial balance, balance sheet, cash-flow statement and formal P&L.
- Bank/cash book, bank reconciliation and treasury management.
- Customer receipt recording, accounts-receivable settlement and collection ledgers.
- Supplier payment recording, accounts-payable settlement and payment reconciliation.
- Tax returns, tax accounting, statutory financial closing and audit-accounting workflows.
- Formal payroll calculation, payroll runs and payroll payment workflows.

The existing database objects and migrations for accounting, payment and payroll domains must not be destructively dropped as part of this scope adjustment. Keep them disabled/unexposed from the operational UI unless a future explicit owner decision changes the scope. Do not route customer receipts or supplier payments into the operational expense tracker.

## 5. Important boundary: operational costs are not payment ledgers

An incidental-cost record exists to measure the cost of doing business and calculate operational profitability. It is not a general cashbook, employee reimbursement system, supplier payment ledger or accounting journal.

For payments that may be legally or ethically sensitive, record the actual purpose and recipient transparently, flag them for review where appropriate, and never disguise, mislabel or facilitate an unlawful payment. Referral fees should have a clear business purpose and appropriate authorization.

## 6. Current backend gap identified during the 2026-11-03 review

The live `public.expenses` table currently has only basic fields (category, amount, description, location, paid_by, created_by and created_at). It does not yet provide the complete cost-phase classification, recipient/purpose controls, links to purchase/shipment/sales/product/customer records, allocation method/basis, unallocated-cost workflow or audit history required above.

Therefore, the existing expenses table is **not yet sufficient** to produce reliable landed gross profit or direct contribution. Reconcile its existing UI writes, RLS and grants before designing a forward-only additive migration. Do not apply unreviewed DDL to the live database.

The existing `sales_payments`, `supplier_payments`, `ledger_accounts`, `fiscal_periods`, `journal_entries` and `journal_lines` objects are not a reason to activate accounting workflows; they remain outside the confirmed operational scope.

## 7. Release and migration acceptance criteria

- Full V6.7 interface is retained; this is not a minimal app or proforma-only release.
- BlackRock is the only active company context; Prime business data is not part of the target operating scope.
- CRM create/read/update workflows persist securely and pass role/company-isolation tests.
- Sales, purchasing, receiving, stock movements, transfers and stock swap workflows persist and reconcile.
- Purchase and selling prices are traceable to source documents and dates.
- Direct costs can be captured, linked, allocated and audited without double counting.
- The three profitability levels reconcile to underlying source transactions.
- No customer/supplier payment or formal accounting workflow is exposed as an enabled module.
- Production authentication, RLS/grants, private document storage, browser persistence tests, backup/export and recovery checks pass before production release.
- Keep production flags disabled and the PR draft until all required gates are verified.
