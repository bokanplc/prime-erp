# Inventory Costing and Receiving Readiness — 2026-11-06

## Purpose

This document records a fresh comparison of the live Supabase database with the repository migration history. It is a release-readiness artifact, not authorization to enable stock posting or to change live production data.

## Verified live state

Project: `kafiwnuynjemufnankvi`

### Live RPC inventory

The live database currently exposes:

- `public.post_sales_document_stock(uuid)`
  - Exists.
  - `SECURITY INVOKER`.
  - Execute ACL currently lists only `postgres` and `service_role`; `authenticated` is not granted execution.
- No live `public.receive_purchase_document(uuid,jsonb)` function was returned by the live function-catalog query.
- No corresponding private-schema implementations for these two stock workflows were found.

This differs from the repository migration history, which contains:
- `20261025161004_atomic_purchase_receiving_and_stock_posting.sql`
- `20261026091615_sales_stock_posting_and_supplier_payment_reconciliation.sql`

The repository migration history alone is not proof that a function is currently present or callable in the live database. Deployment must reconcile this drift explicitly.

### Live stock balance view

`public.inventory_stock_balances` calculates quantity only. It sums:
- Incoming: `opening`, `purchase_receipt`, `customer_return`, `adjustment_in`
- Outgoing: `sale_issue`, `supplier_return`, `adjustment_out`

It does not calculate inventory value or weighted-average unit cost.

### Required sales posting correction

The historical sales-posting implementation inserts `sale_issue` movements with `unit_cost = 0`. This is not acceptable for production because cost of goods sold and gross profit would be misstated.

## Implementation plan (feature branch only)

1. Confirm the inventory cost method with the business owner/accountant before adopting it. Moving weighted-average is the proposed default, not an approved accounting policy.
2. Add a company/product-scoped valuation layer that:
   - preserves each receipt's actual unit cost;
   - incorporates approved direct/landed costs only where allocation and capitalization rules are defined;
   - computes available quantity and carrying value consistently;
   - serializes concurrent movements per company/product;
   - rejects issues that exceed available stock or have no defensible cost basis.
3. Restore a purchase-receiving RPC with the existing document/line/company checks and actual receipt unit costs.
4. Replace sales stock posting so each issued line receives the validated cost at posting time, rather than zero.
5. Make posting idempotent and protect against duplicate line IDs, duplicate issue attempts, and concurrent sales against the same product.
6. Keep the browser API closed until the implementation and role boundaries pass tests. Only then grant the minimum authenticated execute privileges.
7. Do not create supplier-payment or customer-receipt workflows for this release; those remain in Peachtree.

## Minimum acceptance tests

- Opening balance establishes quantity and a documented cost basis.
- One receipt establishes a valid carrying cost.
- Multiple receipts at different costs produce the approved method's expected average.
- Partial receipt values only the received quantity.
- Partial sale consumes the expected cost and updates remaining quantity/value.
- Customer returns restore stock at the approved return-cost policy.
- Supplier returns remove stock at the appropriate carrying cost.
- Direct/landed costs are allocated only under an approved allocation policy and cannot be double-capitalized.
- Insufficient stock and missing/zero cost basis are rejected.
- Repeated posting is blocked without duplicate movements.
- Concurrent sales for the same product cannot oversell or double-consume cost.
- Cross-company product/document IDs are rejected.
- Authenticated role tests prove permitted staff can perform only their intended workflow; anonymous users and unrelated company members cannot.

## Current release decision

- Do not enable sales posting in the browser.
- Do not enable purchase receiving in the browser.
- Do not change live stock quantities or create opening movements from incomplete source data.
- Do not enable production modules while costing, workflow RPC drift, and authenticated role tests remain unresolved.
- HR remains excluded from the first-release production tab allowlist per the separate release-scope decision.
