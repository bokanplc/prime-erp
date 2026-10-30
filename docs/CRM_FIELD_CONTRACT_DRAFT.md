# BOKAN ERP V6.7 — CRM Field Contract (Draft)

**Status:** source-derived design draft; not applied to live Supabase.  
**Branch:** `deploy/secure-staging`  
**Scope:** Sales & CRM Command Center, existing Sales customer directory/activity bridge, customer follow-up log, and related opportunity/order/after-sales features.

## 1. Non-negotiable integration decisions

1. Extend the existing `public.customers` master. Do not create `bokan_customers`, `prime_customers`, or another parallel customer master.
2. The canonical company identity is `company_id` (UUID) referencing the existing `public.companies`. Do not store entity names such as “PRIME Investment Group PLC” as the authorization key.
3. The authenticated Supabase user UUID is the actor/owner identity. A free-text salesperson name is display data only, never proof of identity or authorization.
4. Keep CRM activity and reassignment history append-only for normal users. Correct mistakes with an explicit correction/void workflow, not silent deletion.
5. Opportunity, follow-up and after-sales records must be company-scoped and customer-scoped. Cross-company references must fail at the database boundary.
6. CRM must not create or post sales documents. A won opportunity/order must be converted through the existing sales-document workflow and its trusted RPCs.
7. Existing localStorage records remain preview-only until an explicit export/import and duplicate-reconciliation process is approved. No automatic import from the 50-row sample seed.

## 2. Verified live customer master

The live `public.customers` table currently has:

| Column | Type | Null? | CRM disposition |
|---|---|---:|---|
| id | uuid | No | Canonical customer key |
| company_id | uuid | No | Tenant/legal company scope |
| code | text | Yes | Optional customer code |
| name | text | No | Canonical customer name |
| contact_person | text | Yes | Primary contact |
| email | text | Yes | Primary email |
| phone | text | Yes | Primary phone |
| tax_number | text | Yes | Tax identifier |
| billing_address | text | Yes | Billing address |
| notes | text | Yes | General master notes only |
| created_by | uuid | Yes | Authenticated creator |
| created_at | timestamptz | No | Creation timestamp |
| updated_at | timestamptz | No | Update timestamp |

The following CRM UI fields do **not** exist on this live table and must not be assumed:
`location`, `phones`, `current_status`, `assigned_rep`, `lead_source`, `customer_type`, `priority`, `selling_entity`.

The older bridge also references `customer_logs` and `profiles`; neither is part of the verified live public schema. The current auth bridge uses `company_memberships` and `companies`, so the CRM must use that identity model rather than reintroducing `profiles`.

## 3. Source-derived CRM payloads and target disposition

### Customer / account form (`sh-customer-form`)

| Source field | Meaning | Target |
|---|---|---|
| name | Company/customer name | `customers.name` |
| contact | Contact person | `customers.contact_person` |
| phone | Phone / WhatsApp | `customers.phone` |
| email | Email | `customers.email` |
| location | Address / project site | Candidate `customers.service_address` or separate address table; confirm whether it differs from billing address |
| type | Construction, Real Estate, Government, Trading, Corporate, Individual, Other | Candidate `customer_type` enum/check field |
| source | Lead source | Candidate `lead_source` |
| owner | Account owner | `assigned_user_id` FK to authenticated user, not rep name |
| entity | PRIME / BlackRock display choice | `company_id` selected from active membership; UI label is not persisted as authority |
| status | New Lead / Qualified / Quotation / Order Expected / etc. | Candidate `lifecycle_status` |
| priority | Normal / High / Strategic | Candidate `priority` |
| notes | Initial account notes | `customers.notes` on create; later activity should go to activity timeline |

### Salesperson master (`sh-rep-form`)

Fields: full name, phone, email, territory, monthly target ETB, entity, status.

**Design decision:** do not create CRM “salesperson login” records that can diverge from real users. Build a company-scoped salesperson profile/assignment table linked to `auth.users.id` (or a reviewed public employee/user profile relation if one is introduced). Phone/email/name/territory/target/status are profile attributes. The entity choice resolves to a company UUID. A user may only be assigned within the same company unless a specific shared-group policy is designed and tested. User provisioning remains a separate trusted admin workflow.

### Activity timeline

Source UI supports: activity type, notes, result/feedback, next-action type, next-action date, activity date, rep, escalation reason/note and escalated flag. Activity types include calls, WhatsApp/messages, meetings, site visits, samples, quotations, proformas, price discussion, negotiation, payment/order/production/shipment/delivery checks, customer service and sales-order request.

Target: `crm_activities` with:
- `id`, `company_id`, `customer_id`, `actor_user_id`, optional `assigned_user_id`;
- `activity_type`, `activity_at`, `notes`, `customer_feedback`;
- `next_action_type`, `next_action_date`;
- `escalated`, `escalate_reason`, `escalate_note`;
- immutable `created_at` and optional correction metadata.

The existing source’s “delete activity” control is not suitable for production. Production should permit authorized correction/void with reason and audit trail; ordinary deletion is denied.

### Opportunity / purchase requirement

Source fields: customer, product/SKU text, estimated quantity, estimated ETB value, required date, stage, next-action date, competitor, notes, created timestamp.

Target: `crm_opportunities` with company/customer/user ownership FKs; product text retained as a requirement description until the user selects an actual canonical `products.id`. When product is selected, validate company/product compatibility. Store quantity and estimated value as numeric with nonnegative checks; currency must be explicit (ETB for the current UI). Stage transitions should be validated and audited. “Won” does not automatically create an invoice or stock movement.

### Orders and after-sales

The current CRM command-center “orders” are local operational trackers with product text, quantity, ETA and a free-form status lifecycle. They are not the canonical sales transaction. Do not store them in `sales_documents` until they are actual sales documents.

Target either:
- a narrowly named `crm_order_trackers` table linked to an opportunity/customer and later to `sales_documents.id`; or
- remove this parallel tracker and derive actual order status from canonical `sales_documents` plus fulfilment/delivery tables.

Decision required during detailed design: the second option is preferred if all displayed stages can be represented by canonical sales/fulfilment records.

After-sales tasks: `crm_after_sales_tasks` with company/customer, optional sales document, owner, due date, task type, notes, status/completed timestamp and actor audit.

### Reassignment

Current legacy flow performs two independent writes: update customer assignment, then insert a reassignment log. A failure between them leaves the customer changed without its history.

Target: one trusted database RPC transaction that:
1. validates caller’s active company membership and manager/admin authority;
2. validates customer and new owner belong to the same company;
3. updates the canonical customer assignment;
4. appends an immutable reassignment/activity event with old owner, new owner, actor, timestamp and reason;
5. commits both or neither.

The RPC must not accept a caller-supplied actor UUID; actor is derived from `auth.uid()`.

## 4. Company and role rules

- Every CRM row carries `company_id`.
- Composite foreign keys should prevent linking a customer, owner, opportunity or activity from a different company.
- RLS must check active `company_memberships` via the existing private helper functions.
- Sales users see only records in their company and, where appropriate, their assigned accounts; managers/admins see the company’s permitted CRM scope.
- A shared group/holding-company view must be explicitly modeled; the current “All” UI filter must not bypass company RLS.
- Do not infer role from a browser localStorage value or display label.
- No policy should grant cross-company access just because the same user belongs to both companies; the selected company context is still checked server-side.

## 5. Required migration/test sequence

1. Confirm complete source payloads and all CRUD/read paths for CRM, call log, follow-up and opportunity lifecycle.
2. Decide whether salespeople map directly to Auth users or to a reviewed employee directory linked to Auth users.
3. Finalize field lengths, numeric precision, enums, uniqueness and customer duplicate policy.
4. Draft a forward-only migration extending `customers` and adding only necessary CRM tables/functions/indexes.
5. Test in disposable PostgreSQL: two-company isolation, wrong-role denial, anonymous denial, invalid customer/owner FKs, duplicate customer rules, activity immutability, reassignment atomic rollback, and concurrent assignment changes.
6. Add Supabase Auth/JWT integration tests and browser create/reload/cross-device persistence tests.
7. Only then submit the reviewed forward migration for live application. Do not fabricate or replay missing historical migrations.
8. Keep all production module allowlists empty until these tests and the release-candidate checks pass.

## 6. Explicit unresolved questions (must not be guessed)

- Is “location” a project/site address distinct from billing address?
- Can a customer be assigned to multiple salespeople, or exactly one primary owner plus backup?
- Is the sales target monthly per salesperson and per company, and should historical targets be retained?
- Are salespeople always authenticated ERP users, or do some require non-login employee records?
- Should the order tracker be removed in favor of canonical sales documents and fulfilment records?
- What are the approved status transitions and who can change each transition?

## 7. Safety status

This is a design artifact only. No live schema, customer records, memberships, role grants, or production deployment were changed by this draft.
