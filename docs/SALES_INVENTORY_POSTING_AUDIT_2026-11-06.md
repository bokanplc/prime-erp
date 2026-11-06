# BOKAN ERP V6.7 — Sales and inventory posting audit

**Audit date:** 2026-11-06  
**Scope:** BlackRock Investment PLC; HR remains deferred  
**Branch:** main  
**Disposition:** Do not enable sales/inventory production tabs yet.

## Verified live state

- Sales documents: 28 draft invoices; 0 posted; aggregate grand total ETB 0.00.
- Purchase documents: 16 draft supplier invoices; aggregate grand total ETB 28,754,500.00.
- Stock movements: 0.
- Transaction costs: 0.
- CRM activities, opportunities and after-sales tasks: 0.
- Only one active company membership exists (administrator); employee memberships are not provisioned.
- All 48 public base tables have RLS enabled.
- The latest public API hardening migration revoked EXECUTE on all public functions from authenticated, then explicitly re-granted only selected RPCs. The live sales/purchase posting RPCs currently show EXECUTE only for postgres and service_role, not authenticated. This is fail-closed, but the browser cannot call them.

## Critical source defect: sales COGS is currently zeroed

The live `public.post_sales_document_stock(uuid)` implementation inserts each `sale_issue` movement with `unit_cost = 0`.

The stock-balance view calculates quantity only; it does not provide a valuation cost. The profitability screen calculates COGS as quantity multiplied by the `unit_cost` recorded on sale_issue movements. Therefore, if the current RPC were enabled as-is, every posted sales issue would record zero COGS and materially overstate gross profit.

Do not grant authenticated EXECUTE on this RPC and do not post any historical or live invoice until this is corrected.

## Required correction before activation

1. Adopt and document one inventory valuation method for BlackRock (recommended: moving weighted-average cost unless the owner/accountant directs otherwise).
2. Add a trusted valuation function that calculates available quantity and weighted-average cost from opening balances and purchase receipts, with deterministic row locking per company/product.
3. Update sales stock posting to use the calculated cost, reject insufficient stock, reject unlinked product lines, and remain idempotent under concurrent/repeated requests.
4. Ensure purchase receiving validates product/company ownership and records actual received unit cost; it must not create stock from unapproved documents.
5. Add disposable-database tests for opening balance, partial receipts, multiple receipts at different costs, partial sale, returns, insufficient stock, duplicate posting, concurrent sales of the same product, and company isolation.
6. Only after those tests pass, grant authenticated EXECUTE to the intended RPCs and verify the sales, inventory and manager role matrix through real JWT/Data API sessions.
7. Wire the V6.7 browser screens to the approved RPC contracts; do not fall back to direct browser writes for document approval or stock posting.

## Existing owner boundaries

- Customer receipts and supplier payments stay in Peachtree; do not enable ERP payment recording.
- Do not invent missing sales prices or opening stock.
- Keep the 61-piece opening-stock row unposted until the source/ownership reconciliation is confirmed.
- Keep the two additional Argaw legacy lines intact pending reconciliation; do not delete them automatically.
- HR/payroll/attendance/leave/performance workflows are outside this initial release scope.
- Keep production mode and the reviewed production-tab allowlist disabled until acceptance tests pass.

## Next engineering task

Implement the moving weighted-average valuation path and its database tests as a forward migration on a feature branch. Do not apply an untested valuation migration to the live database and do not deploy it directly to production.
