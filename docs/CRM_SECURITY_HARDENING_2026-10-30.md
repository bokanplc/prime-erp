# BOKAN ERP V6.7 — CRM persistence and authorization hardening (2026-10-30)

## Scope

This checkpoint improves the existing company-scoped CRM candidate. It does not apply the candidate to live Supabase and does not enable the CRM UI in production.

## Existing live dependencies verified

- The live canonical customer master is `public.customers`, keyed by `id` and `company_id`, with a unique composite key on `(company_id, id)`.
- Live company authorization is based on `public.company_memberships(company_id, user_id, role, is_active)`.
- Existing private helpers are present and SECURITY DEFINER with an empty search path:
  - `private.has_company_membership(uuid)`
  - `private.can_manage_company(uuid)`
- The CRM candidate adds five tables without creating a parallel customer master:
  - `crm_customer_assignments`
  - `crm_assignment_events`
  - `crm_activities`
  - `crm_opportunities`
  - `crm_after_sales_tasks`

## Security corrections committed

1. Customer ownership changes are restricted to the atomic `bokan_reassign_customer_owner` RPC. Authenticated users no longer receive direct UPDATE permission on `crm_customer_assignments`; reassignment and its append-only event remain in one transaction.
2. Opportunity ownership updates now require the resulting owner to remain an active member of the same company.
3. After-sales task ownership updates now require an active same-company owner; non-manager owners cannot transfer a task to another user.
4. Opportunity and after-sales UPDATE grants are column-scoped. Tenant/customer/creator identity columns are not in the writable column lists.
5. Assignment history and CRM activity remain without ordinary UPDATE/DELETE grants or policies.

## Additional disposable-database tests added

- Direct assignment-table UPDATE must be denied.
- A sales owner must not transfer their after-sales task to another member.
- A sales owner must not transfer their opportunity to another member.
- Existing tests cover manager-only reassignment, inactive assignee rejection, cross-company reassignment denial, company-level read isolation, and append-only assignment history.

The SQL was applied to live Supabase on 2026-10-31 as migration `20261031081151_add_company_scoped_crm_foundation`; the applied SQL body remains in `supabase/candidates/crm_company_scoped_v1.sql` while the repository source-parity guard is reconciled. The isolated PostgreSQL CRM smoke test passed. A green isolated test is necessary but not sufficient: real Supabase JWT/Data API and browser persistence tests are still required.

## Live rollout status

- Five company-scoped CRM tables have been created in live Supabase with RLS enabled.
- No CRM customer records have been imported.
- No CRM module has been added to the production allowlist.
- Production mode remains disabled.
- The four missing historical SQL migration bodies remain unrecovered. Do not fabricate or backdate them; add only forward migrations after schema parity is documented.

## Remaining work before CRM activation

1. Confirm the disposable PostgreSQL workflow passes with the strengthened candidate.
2. Reconcile the applied SQL body with the repository's executable migration source layout.
3. Test actual Supabase Auth/JWT and PostgREST behavior for BlackRock manager/sales, Prime manager/sales, inactive memberships, and anonymous access.
4. Wire the V6.7 CRM customer/activity/opportunity/after-sales screens to these exact contracts, including persistence after reload and on a second session.
5. Add a controlled correction/void path for mistaken activities and reassignment events, without granting ordinary deletion.
6. Keep the module disabled until the above evidence is recorded.


## Applied live foundation — 2026-10-31

The five CRM tables and the manager-only reassignment RPC are now present in the live Supabase project. RLS is enabled on all five tables. The RPC is granted to authenticated users only and checks the active manager membership and target owner's active membership before writing the assignment and immutable event together. The current V6.7 CRM bridge still uses legacy `bokan_*` table names, so the UI has not been switched to this backend and the CRM production tab remains disabled.
