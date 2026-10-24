# BOKAN ERP V6.7 — Schema Design Decision Register

**Status:** unresolved design register; no DDL has been applied.  
**Updated:** 2026-10-21  
**Project:** Supabase `kafiwnuynjemufnankvi` (Free plan)  
**Branch:** `deploy/secure-staging`

This register separates source-code facts from architecture decisions. The source uses both legacy and newer tables; names alone are not enough to define a production schema. Do not create all referenced names blindly.

## 1. Proposed core relational foundation (design proposal only)

### Company / tenant identity
- Use one canonical company master for the two legal entities and any explicitly approved group-level scope.
- Company-owned records should carry a non-null canonical company foreign key. During transition, legacy `company_code` and newer `company_id` / `legal_owner_company_code` fields must be reconciled instead of treated as interchangeable.
- Where legal ownership and operational ownership differ (shipments/delivery), model both explicitly and authorize each field separately. A row cannot be reassigned across companies merely by editing the browser payload.
- An admin authorized for both companies must have an explicit membership for each; do not treat a `GROUP` localStorage value as membership.

### Identity / role
- `profiles.id` should reference `auth.users.id` and be provisioned through a trusted process.
- If a person can work across both companies, replace the single-company assumption with a company-membership relation such as `profile_company_memberships(profile_id, company_id, role, active)`, subject to business approval. Keep a profile's global account status separate from company-specific membership and role.
- Do not store permissions in editable user metadata. No user should be able to self-update their role, company membership, active state, or termination state.
- Keep a simple `profiles.role` only if the business confirms one role per user globally; otherwise define membership-scoped roles.

### Auditability
- High-risk writes should carry actor, timestamp, company, operation, and correlation ID. Business transactions should use status transitions and reversals instead of hard deletes.
- Audit records should be append-only for ordinary clients.
- Use server/database constraints for invariants that must hold under direct API calls and concurrent requests.

These are proposals for review, not a migration or claim about the current live schema.

## 2. Canonical model decisions

| Area | Source evidence | Recommended design direction | Decision still required |
|---|---|---|---|
| Customer / CRM | Both `customers` + `customer_logs` and `bokan_customers` + activities/assignments/opportunities are referenced | Pick one canonical customer identity and map legacy screens through an adapter; preserve activity and assignment history | Which screens/workflows must remain, and whether existing local-only records are real or demo data |
| Employees / HR | Both `employees` / legacy HR tables and `bokan_employees` / modular HR tables are referenced | One employee master, with attendance, leave, review, disciplinary and payroll records referencing stable employee IDs | Which model is current for each HR workflow; employee self-service scope |
| Leave requests | `leave_requests` and `bokan_leave_requests` both referenced | One canonical request lifecycle and approval model | Whether legacy requests need import/mapping |
| Performance reviews | `performance_reviews` and `bokan_performance_reviews` both referenced | One canonical review model, sensitive HR permissions, immutable review history | Whether older reviews need migration |
| Proformas | Legacy `proformas` is used for create/list/version; two number RPC names exist | One company-scoped numbering function, unique constraints, immutable issued snapshots and explicit draft/issue/void/revise transitions | Exact number format and whether a legacy number format must be preserved |
| Finance / ledger | Modular `bokan_*` finance tables referenced; legacy expenses/stock/billing coexist | Choose authoritative tables per accounting transaction and define posting/reversal flows before enabling finance | Chart of accounts, tax/period rules, posting responsibilities and opening balances |
| Company/bank settings | `companies`, `company_bank_accounts`, local settings key referenced | Company master and bank accounts in DB; proforma stores a versioned snapshot, not a live join for historic documents | Who can maintain bank data; required audit retention |
| Documents | `documents` metadata + Storage bucket `documents`; source calls public URL helper | Private bucket, metadata tenant/category scope, short-lived signed download flow; keep production writes blocked until ready | Document categories, allowed roles, retention and maximum sizes |
| Notifications | `notifications` source writes `type, message, meta, read, created_by`; recipient scope unclear | Add recipient identity and company scope; select only own notices unless explicit admin function | Whether broadcast notifications are required and who can broadcast |
| Local storage | Literal keys include customer, proforma request, release, control and transaction keys | Keep only UI preferences in localStorage; move authoritative shared data to DB after payload/shape audit | Which saved local values are real records vs stale/demo state |

## 3. Cross-cutting column and constraint requirements

Do not apply these until actual payloads, joins, nullability and historical compatibility are fully traced.

- Primary keys: stable UUIDs for new relational records unless a specific legacy integration requires another type.
- Foreign keys: explicit references for company, employee, customer, proforma, fiscal period, approver, document metadata, and transaction relationships.
- Company ownership: required for company-owned records; validate foreign-key ownership on parent/child joins and all writes.
- Status fields: use constrained values for lifecycle state, with allowed transitions enforced by trusted code.
- Dates: define business timezone (Ethiopia local time for user-facing workflows) separately from UTC audit timestamps.
- Currency: define currency code explicitly; do not assume every record is ETB unless business rules require it.
- Money: use exact decimal/numeric storage rather than binary floating point; validate arithmetic server-side.
- Quantities/rates: numeric precision and nonnegative rules chosen by item/transaction domain.
- Unique keys: company-scoped proforma number/version, idempotency keys for posting/payment workflows, appropriate external document numbers, and business-specific natural keys.
- Indexes: company + frequently filtered date/status/owner columns, foreign-key columns, and unique keys after query paths are confirmed.
- Deletion: foreign-key delete behavior must be deliberate; use restrict/soft delete/reversal for issued transactions and historical HR/finance data.
- Timestamps: `created_at` and `updated_at` assigned by trusted defaults/triggers, not accepted blindly from browser input.
- RLS: table-by-table SELECT/INSERT/UPDATE/DELETE rules, with UPDATE `USING` and `WITH CHECK`; grants are restricted independently.
- RPCs: least-privilege EXECUTE grants, input validation, tenant validation, concurrency safety, idempotency where needed, and no exposed `SECURITY DEFINER` shortcut.

## 4. Safe migration sequence

1. Complete the source write-payload/join inventory.
2. Confirm which duplicate models are canonical and how any genuine existing records are mapped.
3. Design the tenant membership relation and role-to-capability matrix.
4. Create schema locally or in a disposable test project; do not experiment against production.
5. Add constraints, indexes, RLS policies and grants together; verify exposed-schema access.
6. Seed synthetic PRIME and BlackRock companies plus test users/records only in test.
7. Run cross-tenant, role, invalid-value, concurrent-numbering, persistence and storage tests.
8. Run Supabase Security and Performance Advisors and fix findings.
9. Review a migration file and rollback/recovery plan.
10. Only then consider a controlled production migration and hosting configuration change.

## 5. Free-plan operational constraints

- Do not upgrade the Supabase plan or add paid backup products without explicit user approval.
- No production backup capability should be assumed. Before real data is entered, define and test manual database exports and protected document export/recovery procedures appropriate to the free plan.
- Do not enable production mode until the application is tested against a provisioned schema and role/company-separated test accounts.
- No service-role/secret key belongs in the browser or Git repository.

## 6. Current factual state

Read-only checks on 2026-10-21 reported no public application tables and no migration history in the connected Supabase project. Therefore, the app has not yet been proven to persist data in this project. No database changes are made by this document.


## Trusted proforma write boundary update (2026-10-24)
- Direct authenticated INSERT/UPDATE/DELETE on `public.proformas` is revoked; clients read rows and save only through the RPC.
- The exposed `public.bokan_save_proforma` wrapper remains SECURITY INVOKER and delegates to `private.bokan_save_proforma`.
- The private implementation is SECURITY DEFINER only because direct INSERT is revoked. It uses an empty search path and explicit actor/profile/company/role validation, with EXECUTE revoked from PUBLIC/anon and granted to authenticated.
- The private schema must not be added to Supabase's exposed Data API schemas. Do not apply this draft to the current Supabase project until the full test gate passes and the exact deployed function owner/grants are reviewed.
