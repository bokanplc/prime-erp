# Live Supabase Schema and Access Audit — 2026-10-26

Environment: project `kafiwnuynjemufnankvi`. This is a read-only catalog audit; no business rows were read or changed.

## Verified current state

- 12 public application tables; all 12 have RLS enabled.
- 42 RLS policies on public tables.
- 0 direct table grants to `anon`.
- 97 table privileges granted to `authenticated`; effective row access remains dependent on RLS.
- 2 public views; 0 public-schema SECURITY DEFINER functions.
- 0 deployed Supabase Edge Functions.
- 15 recorded migrations.
- Security Advisor still reports leaked-password protection disabled.
- Performance Advisor reports 24 unused-index informational findings. Do not remove indexes automatically based on this notice.

Tables observed: `companies`, `company_memberships`, `customers`, `products`, `sales_documents`, `sales_document_items`, `suppliers`, `purchase_documents`, `purchase_document_items`, `stock_movements`, `sales_payments`, `supplier_payments`.

## Access-control observations

Inspected policies use `private.has_company_membership(...)` and `private.can_manage_company(...)` helpers to scope access by company. Role checks distinguish sales/staff, inventory, accountant, and manager operations. Update policies observed for mutable records include both `USING` and `WITH CHECK`. Sales line-item policies also verify the parent document company and role access.

These catalog observations are not proof of effective security. Remaining tests must use real Auth sessions for PRIME and BlackRock and attempt cross-company reads, inserts, updates, deletes, company reassignment, inactive-membership access, and removed-membership/session cases. Inspect the two public views for invoker/definer behavior and grants, and review function EXECUTE grants and helper functions outside `public`.

## Full V6.7 coverage gap

The staged source inventory lists 55 logical table names. The live 12-table foundation covers part of sales, procurement, and inventory, but not the broad HR/payroll, journals/GL, AR/AP, logistics, documents, notifications, and legacy module surface. Similar names in old and new models must be reconciled rather than created mechanically.

The full app still contains legacy `/api/*` adapter calls, localStorage/mock-backed modules, and public-document URL paths. No Supabase Edge Functions are currently deployed to provide the missing API. The review build is demo-only and must not be used for real operational records.

## Safe next sequence

1. Keep production mode and full-data enablement disabled.
2. Reconcile the 15 live migration records with committed SQL sources and document unrecovered migration bodies.
3. Finish exact field/payload mapping for Auth/membership, customers/CRM, and Proforma.
4. Resolve the live `companies + company_memberships` identity model versus the older Proforma candidate's `companies + profiles` assumptions before creating an integration migration.
5. Implement and test trusted write paths, then run browser end-to-end tests against test users and non-production data.
6. Add private Storage and signed downloads before enabling document workflows.

## Guardrails

No schema, data, grant, Auth-setting, key, billing, or deployment changes were made by this audit. Do not apply `docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql` unchanged to live Supabase, and do not bypass the readiness gate by toggling flags. The 24 unused-index notices are informational, not instructions to delete indexes.
