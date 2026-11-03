# BlackRock V6.7 — Operational Cost Capture Source Audit

**Audit date:** 2026-11-03  
**Branch:** `feature/blackrock-only-v67`  
**Purpose:** Reconcile the current V6.7 expense UI and live Supabase expense model against the owner's confirmed operational-cost and profitability requirements. This is a design/audit artifact, not an applied database change.

## 1. Current source behavior found

The full HTML source currently has a generic **Standard Expenses Form** under Data Entry. Its submitted Supabase payload contains only:
- `category`
- `amount`
- `description`
- `location`
- `paid_by`
- `created_by` on insert

The form does not capture a separate expense date, cost phase, named recipient/payee, structured purpose, review state, supporting evidence, or links to purchase, shipment, product, sales document, delivery order or customer. It has edit/delete behavior but no visible allocation workflow.

Expense categories are populated from `CHART_OF_ACCOUNTS`, including:
- Direct Cost / COGS
- Selling & Distribution
- Administrative / G&A
- Personnel / Payroll

This is an accounting-chart-oriented taxonomy, not the operational cost taxonomy the owner requested. The expense screen should become an operational cost register; it must not become a cashbook or payment ledger.

## 2. Current source reporting risks

The existing overview and board report calculate:
- Revenue from `stock_entries` rows marked `sale`.
- "Direct cost" from the sum of all `stock_entries` rows marked `purchase`.
- Additional direct cost from expense categories labelled `Direct Cost / COGS`.
- Net margin by subtracting those amounts and other expense groups.

This is not a reliable landed gross-profit calculation:
- Purchases in a period are not necessarily the cost of goods sold in that period; unsold purchases remain inventory.
- The same inbound freight/handling could be counted in both purchase cost and direct-cost expense if the purchase value already includes it.
- Expenses are grouped only by text category, not by purchase batch, shipment, product or sales delivery.
- There is no explicit allocation basis or unallocated-cost treatment.
- The monthly report also estimates VAT and corporate income tax. These tax/accounting estimates are outside the owner's requested operational product scope and must not be presented as official financial reporting.

Until stock-cost flow and expense allocation are reconciled, label these legacy totals as historical/indicative only and do not use them as the new operational gross-margin source of truth.

## 3. Live Supabase `public.expenses` table — verified read-only

Current columns:
- `id uuid`
- `company_id uuid`
- `category text`
- `amount numeric`
- `description text`
- `location text`
- `paid_by text`
- `created_by uuid`
- `created_at timestamptz`
- `updated_at timestamptz`

Current live row count: **0**.

Current RLS policies:
- SELECT: any active company member.
- INSERT: company member, with `created_by = auth.uid()`.
- UPDATE and DELETE: owner/admin/manager/accountant role set.

The authenticated role currently has table-level SELECT, INSERT, UPDATE, DELETE plus unnecessary `TRUNCATE`, `TRIGGER` and `REFERENCES` privileges reported by the read-only grant audit. Tighten these in a reviewed forward-only migration before enabling this module. Do not grant accountant access as a workaround; the accountant remains on Peachtree.

## 4. Related live tables and company-safe relationships

The live schema already provides composite company-scoped keys for:
- `purchase_documents(company_id, id)`
- `sales_documents(company_id, id)`
- `products(company_id, id)`
- `customers(company_id, id)`

The live `supply_shipments` and `delivery_orders` tables currently have company-scoped primary/number keys and delivery-order-to-sales-document linkage, but no observed `UNIQUE(company_id,id)` key for use by composite expense-allocation foreign keys. A reviewed migration can add the required unique indexes if verified against the current live schema before creating company-safe references.

The existing `expenses` table has no composite `UNIQUE(company_id,id)` key yet. A child allocation table should use composite company-scoped foreign keys so an expense from one tenant cannot be attached to a document, shipment, product or customer in another tenant.

## 5. Target operational cost record

Each expense record should have:
- Expense date, currency and amount.
- Operational category.
- Cost phase: `procurement`, `sales_fulfillment` or `overhead`.
- Recipient/payee name where known.
- Clear business purpose/description.
- Location and reference note.
- Entered-by identity and timestamps.
- Review status and review note for unusual/sensitive entries.
- Evidence reference where a safe private-document workflow is available.

Examples include factory product-selection/quality assistance, sourcing or introducer fees, inbound freight, loading/unloading, transport, delivery, handling and other justified direct costs.

Do not collect a customer receipt, supplier payment, bank account or settlement status as part of this register. The legacy `paid_by` field must not be treated as a payment-ledger feature.

## 6. Allocation design

Use a separate allocation child table so one expense can be split across several relevant products or transactions. Each allocation should retain:
- Company and parent expense.
- Optional same-company purchase document, inbound shipment, product, sales document, delivery order and/or customer links.
- Allocated amount.
- Allocation method: manual, quantity, weight, volume, purchase value or sales value.
- Basis quantity/value and an explanatory note.
- Created-by and timestamps.

No source link means the expense remains unallocated. Partially allocated expenses must show their remaining balance. Unallocated or review-pending costs must be visible and excluded from finalized product/order profitability until resolved.

Use procurement-phase allocations to calculate landed product cost. Use sales-fulfillment allocations to calculate direct contribution after landed gross profit. Overhead is tracked separately and excluded from the owner's requested merchandise/direct-contribution margin.

Allocation totals must not exceed the source expense amount. Corrections should be auditable; avoid silent edits that erase the previous allocation history. Enforce same-company references with composite foreign keys and RLS. High-risk multi-step allocation/posting should use a tested transactional database boundary rather than trusting browser calculations.

## 7. Profitability acceptance rules

1. **Merchandise gross profit:** sales revenue less the inventory cost of the quantities actually sold, not all purchases made in the reporting period.
2. **Landed gross profit:** merchandise gross profit after allocated procurement/inbound costs are incorporated into the relevant stock/product cost.
3. **Direct contribution:** landed gross profit less allocated sales/outbound fulfilment costs.

Reports should support product, purchase batch, sales document, customer, salesperson and date range where source data supports those dimensions. Show cost basis, margin percentage, allocation completeness and any estimated/missing amounts.

Before enabling margin reporting, reconcile how V6.7 stock movements represent receipt, issue, transfer, swap, return and cost. Select and document a consistent inventory costing method and ensure each stock movement is posted exactly once.

## 8. Immediate engineering sequence

1. Keep the live database read-only while reconciling the source, RLS, grants and existing migration history.
2. Replace the legacy chart-of-accounts expense UI with an operational cost-entry experience; retain legacy records/columns safely.
3. Prepare an additive candidate migration for cost fields, company-scoped allocation rows, indexes, RLS/grants, audit history and allocation integrity checks.
4. Test candidate SQL in disposable PostgreSQL, including cross-company rejection, member/manager permissions, allocation sum limits, unallocated/partial/full allocation, reversals/corrections and deletion restrictions.
5. Rework overview/report calculations to use posted inventory cost of goods sold plus allocated inbound/outbound costs; remove statutory tax/accounting calculations from the enabled operational dashboards.
6. Run browser tests against a non-production Auth user before any production feature flag is enabled.

**Stop-ship note:** The existing expense screen and current margin/tax reports do not yet satisfy the owner-confirmed scope. The presence of an `expenses` table is not evidence that landed-cost profitability is implemented.
