# Live Supabase RPC Contract Gap — 2026-10-26

## Scope and safety

This is a read-only reconciliation of the connected Supabase catalog against literal RPC calls in
`staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`. No live database, Auth, Storage, or deployment
changes were made. This is not an approval to enable production mode.

## Frontend RPC references not found in the current live public-function catalog

| Frontend RPC | Frontend purpose | Current status |
|---|---|---|
| `bokan_save_proforma(p_company, p_existing_id, p_payload)` | Atomic company-scoped Proforma create/update and revision save | **Missing from live catalog.** Production Proforma save cannot be considered verified until the function and its table/tenant/role contract are designed, reviewed, migrated, and tested. |
| `next_proforma_no()` | Legacy fallback Proforma number allocation | **Missing from live catalog.** Do not rely on the fallback for production numbering; use one concurrency-safe allocator with a unique constraint and atomic save. |
| `bokan_finance_close_readiness(p_period_id)` | Finance period-close readiness check | **Missing from live catalog.** Finance close readiness must remain unavailable/disabled until its canonical schema and trusted function are implemented and tested. |

These names were extracted from literal `.rpc(...)` calls in the full staging HTML. Absence from the current catalog means the call cannot be verified as working against the connected project; it does not prove that every associated UI path is enabled.

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

1. Design the Proforma tables and atomic save/numbering operation additively against the existing `companies.id` and `company_memberships` model. Do not apply the old `companies/profiles` candidate.
2. Define payload validation, role authorization, tenant isolation, totals/VAT/withholding calculations, version/revision behavior, uniqueness, idempotency, and audit fields before implementing the RPC.
3. Add the finance close-readiness RPC only after fiscal-period, journal, AR/AP, and company models are canonical and reviewed.
4. Add forward-only SQL migration files on the staging branch, test against disposable PostgreSQL, run static checks/advisors, then use non-production Auth sessions for positive and negative cross-company tests.
5. Keep `PRODUCTION_MODE`, `FULL_ERP_DATA_READY`, and production module allowlists disabled until the full workflow passes.

## Important limits

Catalog inspection does not prove successful RPC execution for authenticated users, company isolation, correct financial outcomes, or complete module coverage. These require non-production session-based tests and actual browser workflow tests.
