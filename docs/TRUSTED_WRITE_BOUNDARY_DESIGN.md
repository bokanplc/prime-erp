# BOKAN ERP V6.7 — Trusted Write Boundary Design

**Status:** proposed API contract only; no database functions or schema changes have been applied.

## Why this is needed

The modular production bridge currently performs several high-impact writes directly from browser JavaScript. RLS is essential, but row-level policies alone do not make a multi-step business operation atomic, validate all financial invariants, or prevent a permitted user from submitting an invalid business payload. These operations must not be enabled until a trusted transaction boundary exists.

## Operations that require a trusted boundary

| Operation | Current browser pattern | Required production design |
|---|---|---|
| CRM customer reassignment | Insert assignment-history row, then update customer assignment in a second request | One transaction: validate actor/role/company, validate salesperson belongs to company, record previous/new owner, update customer, return committed result |
| Proforma numbering/versioning | RPC references include `bokan_next_proforma_number` and legacy `next_proforma_no` | One company-scoped concurrency-safe allocator; unique constraints; one transaction to allocate and persist; revision/void lifecycle checks |
| Journal posting | Direct insert to `bokan_journal_entries` | Trusted posting operation validates accounts, company, open fiscal period, balanced debit/credit, reference uniqueness, and idempotency; posted entries are immutable |
| AR invoice / receipt | Direct inserts to `bokan_ar_invoices` and `bokan_ar_receipts` | Validate customer/company, currency, invoice balance, allocations, receipt uniqueness and idempotency; post atomically |
| AP bill / payment | Direct inserts to `bokan_ap_bills` and `bokan_ap_payments` | Validate supplier/company, invoice balance, payment allocations, authorization and idempotency; post atomically |
| Payroll run/line/approval | Direct inserts to `bokan_payroll_runs`, `bokan_payroll_lines`, `bokan_payroll_approvals` | Enforce payroll lifecycle, company/period, calculations, preparer/approver separation, duplicate prevention, immutable approval/post state |
| Bank-account replacement | Delete all company's rows, then insert replacement rows | One atomic, audited transaction with explicit add/update/deactivate semantics and historical snapshot preservation |
| Document upload/delete | Upload object, obtain public URL, write metadata; delete object/metadata separately | Private bucket; authorize company/category/record; upload to scoped path; store metadata; signed download; retry-safe cleanup; never rely on public URL |
| Role/company membership changes | Browser updates `profiles.role` | Dedicated admin provisioning flow; protect role/company/status columns from ordinary client writes; log actor and change |
| Stock movement | Browser writes source entry and ledger via separate calls | Trusted inventory transaction with idempotency, balance checks, source linkage, and compensating reversals |

## RPC design principles

- Prefer `SECURITY INVOKER` and ordinary RLS/grants.
- Do not create a `SECURITY DEFINER` function just to make an operation work. If a privileged function is demonstrably necessary, keep it in a non-exposed schema, pin `search_path`, validate the authenticated actor and company inside the function, restrict EXECUTE grants, and run security advisors.
- A browser-supplied `company_code`, role, `created_by`, owner, total, approval status, or posted status is input, not authority.
- Use `auth.uid()` as actor identity. Derive company membership and capabilities from protected database records.
- Use database constraints for invariants that can be represented declaratively.
- Make retries safe with an idempotency key for payment, receipt, posting, upload metadata, and other non-repeatable operations.
- Return only the minimum data needed by the client.
- Record actor, company, operation, entity ID, correlation/idempotency key, and timestamp for high-risk state changes.
- Do not expose service-role or secret keys to browser code.
- Test calls made directly through the Data API, not only through UI handlers.

## Current client safeguards

- Role-change UI validates the allowed role list and blocks production role changes from non-admin profiles; the database must still enforce it.
- Production bank-account replacement is blocked pending an atomic audited implementation.
- Production document upload/delete is blocked pending private Storage and signed-download design.
- Hosted preview identity is blocked, startup fails closed, and production mode remains disabled.
- This does **not** mean all other direct browser writes are safe. Finance posting, payroll, assignment, stock, and legacy CRUD require schema-specific policies/constraints and trusted workflow design before production is enabled.

## Release condition

No production mode, live deployment, or business data entry until each listed operation is implemented or deliberately disabled, its database schema and policies are reviewed, and tests cover both successful authorized requests and direct unauthorized API attempts.
