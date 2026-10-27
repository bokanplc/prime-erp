# Live Supabase RPC Contract Gap — 2026-10-26

## Scope and safety

This is a read-only reconciliation of the connected Supabase catalog against literal RPC calls in
`staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`. No live database, Auth, Storage, or deployment
changes were made. This is not an approval to enable production mode.

## Frontend RPC references not found in the current live public-function catalog

| Frontend RPC | Frontend purpose | Current status |
|---|---|---|
| `bokan_save_proforma(p_company, p_existing_id, p_payload)` | Atomic company-scoped Proforma create/revision save | **Still missing from live catalog.** A UUID-company-aligned candidate now exists at `supabase/candidates/live_company_proforma.sql`; it has not been applied to live Supabase and still requires disposable PostgreSQL and browser verification. |
| `next_proforma_no()` | Legacy/demo fallback Proforma number allocation | **Missing from live catalog.** The production save bridge should use only the atomic save RPC, never allocate a number separately from the save transaction. |
| `bokan_finance_close_readiness(p_period_id)` | Finance period-close readiness check | **Missing from live catalog.** Finance close readiness must remain unavailable/disabled until its canonical schema and trusted function are implemented and tested. |

These names were extracted from literal RPC references in the full staging HTML. The staging source now also calls `bokan_save_company_proforma_settings(p_company, p_payload)` for authorized issuer TIN/address/phone changes; this RPC is also absent from the live catalog and exists only in the un-applied candidate SQL. Absence from the current catalog means the call cannot be verified as working against the connected project; it does not prove that every associated UI path is enabled.

## Current public RPC inventory

The live catalog currently reports these public functions:

- `approve_purchase_document(p_purchase_document_id uuid)`
- `approve_sales_document(p_sales_document_id uuid)`
- `create_purchase_document_with_items(p_document jsonb, p_items jsonb)`
- `create_sales_document_with_items(p_document jsonb, p_items jsonb)`
- `post_sales_document_stock(p_sales_document_id uuid)`
- `receive_purchase_document(p_purchase_document_id uuid, p_items jsonb)`
- `reconcile_supplier_payment(p_payment_id uuid, p_bank_reference text, p_reconciled boolean)`
- `record_supplier_payment(p_payment jsonb)`

Correction: the catalog contains **eight** public functions in the list above. They are currently reported as SECURITY INVOKER, with EXECUTE granted to authenticated (and service_role); their actual behavior still requires contract and authorization tests.

The private schema also contains `has_company_membership(uuid)` and `can_manage_company(uuid)`. Both are SECURITY DEFINER with an empty search_path and EXECUTE granted to authenticated; their definitions derive the actor from `auth.uid()` and require an active company membership. Keep these helpers private and review all call paths before any changes.

## Required next steps

1. Review and test the new UUID-company candidate and issuer-settings RPC in disposable PostgreSQL; do not apply the old `companies/profiles` candidate or the new candidate to live yet.
2. Define payload validation, role authorization, tenant isolation, totals/VAT/withholding calculations, version/revision behavior, uniqueness, idempotency, and audit fields before implementing the RPC.
3. Add the finance close-readiness RPC only after fiscal-period, journal, AR/AP, and company models are canonical and reviewed.
4. Add forward-only SQL migration files on the staging branch, test against disposable PostgreSQL, run static checks/advisors, then use non-production Auth sessions for positive and negative cross-company tests.
5. Keep `PRODUCTION_MODE`, `FULL_ERP_DATA_READY`, and production module allowlists disabled until the full workflow passes.

## Important limits

Catalog inspection does not prove successful RPC execution for authenticated users, company isolation, correct financial outcomes, or complete module coverage. These require non-production session-based tests and actual browser workflow tests.
