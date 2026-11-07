> **Scope status — 2026-11-07:** This is a historical technical/data audit only. The owner has since directed that stock information, sales stock posting, purchase receiving, inventory costing, and historical data reconciliation be parked. Do not treat this document as an active migration task or release blocker. The current scope is defined in `docs/V67_APPLICATION_MIGRATION_SCOPE_2026-11-07.md`.

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
- `public.receive_purchase_document(uuid,jsonb)` exists, but its live execute ACL currently lists only `postgres` and `service_role`; authenticated ERP users cannot execute it.
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
3. Harden the existing purchase-receiving RPC with inventory/manager role checks, product-company validation, positive unit-cost validation, and authenticated-only execution.
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
- Do not wire purchase receiving into the browser until its V6.7 screen and authenticated staff workflow are tested.
- The documented Yellow Plywood opening balance is now seeded; do not seed Green/Morale opening stock or import historical stock swaps until their source exceptions are reconciled.
- Do not enable production modules while sales costing, stock-swap exceptions, and authenticated browser tests remain unresolved.
- HR remains excluded from the first-release production tab allowlist per the separate release-scope decision.

## Candidate work added on this feature branch

The forward migration `20261107064845_harden_atomic_purchase_receiving_workflow` has been applied to live Supabase and source controlled. It hardens the existing `public.receive_purchase_document(uuid,jsonb)` with:

- active inventory-role or company-management authorization;
- approved/partially received document status checks;
- purchase-order/supplier-invoice type checks;
- company/product ownership checks and row locking;
- duplicate-line and over-receipt rejection;
- positive documented purchase unit-cost enforcement;
- atomic received-quantity updates and purchase-receipt stock movements;
- authenticated-only RPC execution.

A disposable PostgreSQL integration test and CI job exercise partial/final receipts, over-receipt, duplicate item IDs, zero-cost rejection, unknown lines, non-inventory role denial, and cross-company denial.

The hardened RPC is now executable by authenticated users. A rollback-only test using the real authenticated admin role successfully approved a draft purchase document, received one unit, verified the update, and rolled the transaction back; the document remains a draft, received quantity remains zero, and no receipt movement was retained. The browser UI is still not wired to this RPC. It does not decide the inventory valuation method or allocate landed costs.

## Opening stock evidence and candidate seed

The original workbook's Daily_Data_Entry opening row records BlackRock opening Yellow Plywood stock on 2026-07-01 as 61 pieces at ETB 4,300 per piece. This yields a documented opening inventory value of ETB 262,300.

The live product mapping was verified as BlackRock Investment PLC → Yellow Plywood. The idempotent seed was applied to live Supabase as migration `20261107064904_seed_blackrock_opening_stock_61_yellow_plywood`. It resolved the company and product by unique names, verified the mapping, and inserted one opening movement for 61 pieces at ETB 4,300 each. The live stock balance now shows 61 Yellow Plywood pieces. The disposable PostgreSQL receiving test also checks this seed before testing receipts.

This is a candidate import only. It has not been applied to live Supabase. It must be reconciled with the source workbook and current stock before a controlled data migration.


## Sales draft creation workflow

Migration `20261107070044_harden_sales_document_draft_creation` is now live. It adds `sales_documents.salesperson_id` for sales-performance attribution and replaces the draft-creation RPC with a guarded SECURITY DEFINER workflow. Sales reps can create drafts only for themselves; data-entry staff can create drafts for an active sales rep (defaulting from the customer's assigned representative); management/accounting can assign an active sales rep. Only `sales_order` and `invoice` drafts are accepted.

Direct authenticated INSERT on `sales_documents` and `sales_document_items` is revoked so new drafts must pass through the validated RPC. A real authenticated-role transaction test created a zero-value draft for the active admin temporarily mapped to the sales role, verified the assigned salesperson and creator, and rolled back. No test sales document remains. The disposable PostgreSQL test also covers staff assignment, self-assignment, manager assignment, invalid document type, cross-company customer/product, viewer denial, and direct-insert denial.

The V6.7 Sales Orders screen is still localStorage-based and has not yet been wired to this RPC. The backend is ready for the next UI bridge step; no new sales documents have been created in live data.
