# BOKAN ERP V6.7 — Draft Authorization and RLS Matrix

**Status:** design-only; not executable policy SQL.  
**Date:** 2026-10-21  
**Scope:** PRIME Investment Group PLC and BlackRock Investment PLC on the shared BOKAN platform.

## Security rules that apply to every module

1. **Identity source:** only a valid Supabase Auth user with a matching active `profiles` row is eligible. A missing profile, inactive account, or non-null `terminated_at` must deny access.
2. **Tenant isolation:** every company-owned record must resolve to one authorized company. A user cannot change a row's `company_code`, `company_id`, legal owner, or operational owner to gain access. Browser localStorage and UI filters are preferences, not authorization.
3. **Trusted role source:** roles/company membership come from a protected profile/membership table or server-controlled claims, never from editable user metadata or browser state. Ordinary users cannot change `profiles.role`, `company_code`, `active`, or `terminated_at`.
4. **Default deny:** no table receives a blanket `TO authenticated USING (true)` policy. No delete permission is granted simply because the UI has a delete button.
5. **RLS and SQL privileges are separate:** grant only required operations to `authenticated`; enable RLS on every exposed table; test both the grants and the policies.
6. **Update checks:** every UPDATE needs a row-visibility condition and a matching `WITH CHECK` that prevents company reassignment, owner reassignment, or role escalation.
7. **Sensitive modules:** HR, payroll, bank account configuration, documents, accounting journals, payments, approvals, and audit data have narrower permissions than general management views.
8. **Privileged routines:** avoid `SECURITY DEFINER`. If one is unavoidable, keep it outside exposed schemas, restrict EXECUTE, validate `auth.uid()` and company access in the routine, pin `search_path`, and audit it.
9. **Server validation:** financial totals, VAT, withholding, proforma versioning/numbering, stock movements, journal balancing, payroll approvals, and payment posting must not trust browser-calculated values alone.
10. **No destructive hard delete for issued business records:** prefer controlled void/reversal and append-only audit history. User access to a delete UI is not proof that deletion should be allowed in production.

## Role definitions to confirm against actual business responsibilities

- **admin:** explicitly provisioned platform administrator; not a synonym for any browser-side role flag.
- **management:** management-level review within assigned company/entities; not automatic access to payroll details, private documents, or credentials.
- **sales_manager:** sales and CRM records for assigned company/team, with controlled assignment and target management.
- **sales:** assigned CRM records, activities, opportunities, visit reports, and own workflow data; no cross-company reads.
- **accounting:** accounting and commercial-finance records for assigned company; payroll details only if separately authorized.
- **hr:** HR personnel records, leave, attendance, performance and payroll workflows within assigned company; payroll approval must be separated from payroll preparation where practicable.
- **data_entry:** create/update only explicitly assigned operational records; no role/profile administration, payroll, unrestricted document access, or financial posting.

These are proposed minimum permissions, not final business approvals.

## Table/module policy matrix

| Data area / current tables | Read | Insert | Update | Delete / reversal | Tenant and row constraints |
|---|---|---|---|---|---|
| `profiles` | User may read own safe profile; admin may read provisioned profiles within authorized scope | Controlled provisioning only | Ordinary users: no role/company/status edits; self-edit limited to explicitly safe fields if needed | No client delete | `id = auth.uid()` for self reads; profile role/membership protected by admin-only provisioning |
| `companies` | Active company display data for authorized companies | Admin-only setup | Admin-only; changes audited | No normal hard delete | Never allow a user to grant themselves a company membership |
| `company_bank_accounts` | Authorized company users who need proforma output; account configuration restricted to accounting/admin | Accounting/admin | Accounting/admin with audit trail | Disable/deactivate rather than delete when referenced by issued documents | Company match required; proforma snapshots preserve historic values |
| `proformas` | Authorized sales, sales managers, accounting and management within company; sensitive fields limited as needed | Sales/authorized data entry under server validation | Draft only; issued versions immutable | Void/revise through audited workflow, not hard delete | Unique company + number/version rules; server-generated numbering; immutable issuer/bank/terms snapshots |
| `custom_terms` | Authorized proforma users within company | Admin/authorized manager | Admin/authorized manager | Disable rather than destructive delete when referenced | Company scope and category allowlist |
| Legacy `customers`, `customer_logs`, `customer_billings` | Sales owner/team, accounting for billing, managers within company | Assigned sales/authorized roles | Assigned owner or manager; billing restricted to accounting | No hard delete for logs/billing; customer merge/archive workflow | Canonical customer model must be chosen before policies are implemented |
| New `bokan_customers`, `bokan_customer_activities`, `bokan_customer_assignments`, `bokan_sales_opportunities`, `bokan_salespeople` | Assigned salesperson/team; managers within company | Sales and sales managers according to entity | Owner edits permitted fields; reassignment manager-only and audited | Activity/assignment history append-only; salesperson departure deactivates | Canonical CRM model and ownership columns must be decided; assignment cannot cross tenant |
| `sales_targets` | Salesperson's own targets; manager/management for authorized team | Sales manager/management | Manager only; sensitive commission fields restricted | No hard delete after period close | Company + period + employee constraints |
| Legacy `employees`, `leave_requests`, `performance_reviews`, `disciplinary_actions` | HR; employee self-service only if product explicitly supports it; managers get minimum necessary | HR / designated workflow | HR / assigned approver; employee cannot approve own request | Sensitive history retained; corrections audited | Canonical HR model decision required; disciplinary notes highly restricted |
| New `bokan_employees`, `bokan_attendance_records`, `bokan_leave_requests`, `bokan_performance_reviews` | HR; managers limited to their reporting scope; employees only their own allowed data | HR and approved attendance/leave workflow | Role-specific; no self-approval | Append-only or controlled correction | Employee identity and company must match trusted profile mapping |
| `bokan_payroll_runs`, `bokan_payroll_lines`, `bokan_payroll_approvals` | HR/payroll preparers; specifically authorized approvers; management only approved summaries if authorized | Payroll preparer/service process | Controlled draft lifecycle; approved/posted data immutable | Never normal hard delete; cancel/reverse with audit | Separate prepare/approve/post duties; company and fiscal period match; all totals validated server-side |
| `expenses`, `per_diem_requests`, `trip_plans`, `visit_reports` | Employee's own records, relevant managers and finance/HR according to field sensitivity | Employee/authorized role | Owner before approval; approver workflow thereafter | Rejected/cancelled status plus audit | Company scope; no approval of own expense/per diem where separation is feasible |
| `stock_entries`, `stock_ledger` | Inventory/logistics and authorized accounting/management | Authorized inventory workflow | Posted ledger entries immutable; adjustments are compensating entries | No hard delete after posting | Item, warehouse, legal owner and company ownership must be validated; prevent negative/duplicate movement as policy decides |
| `bokan_shipments`, `bokan_delivery_orders` | Logistics and relevant sales; customer-sensitive details limited | Logistics/authorized role | Logistics with audit; status transitions validated | Cancel/void with audit | Validate legal owner and operational entity independently; no cross-tenant reassignment |
| `bokan_journal_entries`, `bokan_ar_invoices`, `bokan_ar_receipts`, `bokan_ap_bills`, `bokan_ap_payments`, `bokan_fiscal_periods` | Accounting and authorized management within company | Accounting workflows; posted journals may require controlled RPC | Draft-only before posting; posted records immutable | Reversal entries; closed periods protected | Balanced journal lines, unique references, open-period checks, payment allocation and idempotency required |
| `notifications` | Intended recipient only, plus narrowly scoped admin operations | Trusted workflow writes with recipient and company | Recipient can mark own notice read; cannot rewrite message or target | Recipient may dismiss own notice if supported; audit as required | Current source lacks clear recipient scope; schema contract must add/identify recipient before policies |
| `documents` and Storage bucket `documents` | Authorized users for allowed category + company | Authorized role/category only, private bucket | Metadata updates restricted; file replacement audited | Delete restricted; remove object and metadata atomically or via retry-safe workflow | Private bucket; no public URLs; object path must include validated tenant/record scope; signed downloads short-lived |
| `companies`-related release flags and browser storage | No authorization use | N/A | N/A | N/A | Browser keys such as `prime_release_role` and `bokan_active_company_context` must never grant access |
| All audit/event tables | Narrow audit readers; business roles see their own transaction state only | Trusted workflows | Append-only | No ordinary update/delete | Record actor, timestamp, entity, action, and correlation ID; never store passwords/tokens |

## Required test matrix before enabling production

For every table and every CRUD operation actually used by the UI, run tests with at least:
- no JWT / anonymous client;
- authenticated user with no profile;
- inactive and terminated profile;
- PRIME-only user;
- BlackRock-only user;
- sales user and sales manager;
- accounting user;
- HR user;
- data-entry user;
- administrator;
- a user attempting to modify their own role/company/status;
- a user attempting to change row company/owner on UPDATE;
- a user attempting to read or mutate another tenant's known row ID;
- a user attempting to call RPCs directly rather than through the UI.

Expected result: only explicitly authorized rows and operations succeed. A UI-hidden button is not a passing security test.

## Blockers before SQL can be finalized

1. Resolve canonical CRM and HR tables (legacy vs `bokan_*`) and list every UI path that must remain supported.
2. Trace complete insert/update payloads and joins, not just table names.
3. Add/confirm a trusted company membership model. A single `profiles.company_code` may not support administrators or staff authorized for both companies.
4. Define notification recipients and document category access.
5. Decide whether data-entry staff can edit draft proformas, expenses, inventory, and billing.
6. Confirm HR self-service, manager reporting lines, accounting access to payroll summaries, and who can post/reverse journals/payments.
7. Draft and test schema/grants/RLS together; do not apply policies to a schema that has not been designed and reconciled.

No SQL, RLS policy, grant, Auth setting, Storage setting, or deployment is changed by this document.


## Proforma write privilege refinement (2026-10-24)
Direct table INSERT/UPDATE/DELETE is not granted to authenticated clients for `proformas`. All creation/revision writes go through the authenticated public wrapper and isolated private transaction function. Role/company authorization is revalidated inside the private function; UI role checks are not trusted. The private schema must remain unexposed through the Data API.
