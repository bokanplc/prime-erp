# BOKAN ERP V6.7 — Security and Persistence Test Plan

**Status:** planned test cases; execution requires a provisioned test schema and browser environment.  
**Date:** 2026-10-24

## 1. Gate conditions

Do not enable production mode or deploy a live business workflow until all critical tests pass. Keep the current fail-closed staging configuration in place.

## 2. Authentication and session

| ID | Scenario | Expected result |
|---|---|---|
| AUTH-01 | Load hosted page with production config absent/false | Business application stays hidden; setup/login gate is shown |
| AUTH-02 | Submit wrong email/password | No application access; error shown without sensitive detail |
| AUTH-03 | Valid Auth user but no `profiles` row | Session rejected/sign-out; no business data shown |
| AUTH-04 | Profile inactive or terminated | Session rejected; app hidden |
| AUTH-05 | Unsupported role | Access denied |
| AUTH-06 | Expired/revoked session | App hides or returns to login; no stale protected data |
| AUTH-07 | Startup/network/profile query error | Fail closed; never reveal preview app |
| AUTH-08 | Browser localStorage changed to `admin`, another company, or production mode | No change to server authorization |
| AUTH-09 | Logout then browser Back | Protected data does not remain visible/reusable |
| AUTH-10 | Production auth configured but preview code path forced | No preview identity, mock reads, or mock successful login on hosted origin |

## 3. Tenant isolation

Run each scenario with one PRIME user and one BlackRock user, each with separate known test records.

| ID | Scenario | Expected result |
|---|---|---|
| TEN-01 | PRIME user selects/requests BlackRock row by ID | Zero rows / authorization error |
| TEN-02 | BlackRock user selects/requests PRIME row by ID | Zero rows / authorization error |
| TEN-03 | User inserts record with another company's code | Rejected by database constraint/policy |
| TEN-04 | User updates an allowed row's company/legal owner to another entity | Rejected by `WITH CHECK`/trusted function |
| TEN-05 | User edits localStorage active-company key | Does not grant membership |
| TEN-06 | User calls table API directly bypassing UI filters | Same restrictions apply |
| TEN-07 | Relationship/nested select crosses tenant boundary | Related record is not disclosed |
| TEN-08 | Global list/count/export attempts to include another company | Other tenant excluded |

## 4. Roles and least privilege

| ID | Scenario | Expected result |
|---|---|---|
| RBAC-01 | Sales user calls payroll, disciplinary, bank configuration or profile administration endpoints | Denied |
| RBAC-02 | Data-entry user calls journal-posting or payment-posting path | Denied unless explicitly provisioned for that exact capability |
| RBAC-03 | HR user attempts to alter own role/company/active/termination fields | Denied |
| RBAC-04 | Employee attempts to approve own leave/expense/per-diem request | Denied where separation of duties is required |
| RBAC-05 | Salesperson changes another salesperson's assignment | Denied; manager workflow required |
| RBAC-06 | Ordinary user invokes DELETE on issued proforma, posted journal, payroll, receipt, payment, stock ledger, or audit history | Denied; use audited void/reversal |
| RBAC-07 | User directly invokes each exposed RPC | Only explicitly granted roles and authorized company allowed |
| RBAC-08 | Company administrator attempts to administer the other company | Denied unless an explicit group-level admin membership is provisioned |
| RBAC-09 | Authenticated user directly updates own profile role/company/active/termination fields | Denied by table/column grants and RLS; role changes use a controlled admin process |
| RBAC-10 | Authenticated user directly inserts/updates/deletes company bank-account rows | Denied until an atomic audited maintenance workflow is approved |

## 5. Financial and business invariants

| ID | Scenario | Expected result |
|---|---|---|
| FIN-01 | Proforma item price entered VAT-inclusive | Stored total equals entered inclusive price; VAT is extracted, not added on top |
| FIN-02 | Proforma grand total ETB 10,000 exactly | Withholding threshold does not trigger under the agreed “exceeds 10,000” rule |
| FIN-03 | Proforma grand total above ETB 10,000 with withholding enabled | Withholding = 3% of VAT-inclusive Grand Total; net payable = Grand Total − withholding |
| FIN-04 | Concurrent users request a proforma number | No duplicate number; company-scoped sequence/unique constraint holds |
| FIN-05 | User edits issued proforma after approval | New version/revision created; prior snapshot preserved |
| FIN-06 | Client submits negative quantities, impossible VAT rates, negative totals, or inconsistent totals | Database/trusted function rejects or recalculates |
| FIN-07 | Duplicate receipt/payment request retries after timeout | Idempotency prevents double posting |
| FIN-08 | Journal entry debits differ from credits | Posting rejected |
| FIN-09 | Posting into closed fiscal period | Rejected |
| FIN-10 | Stock movement is duplicated or reversed | Idempotency and compensating movement prevent double count |
| FIN-11 | Authenticated user calls direct INSERT/UPDATE/DELETE on proformas, bypassing the save RPC | Denied by table grants; all creates/revisions use the trusted transaction RPC |
| FIN-12 | User attempts to call the private proforma implementation through the public Data API | Private schema is not exposed; only the public invoker wrapper is exposed to authenticated users |
| FIN-13 | Proforma save is retried concurrently for the same company/prefix or same revision | Transaction advisory lock and unique constraint prevent duplicate number/version rows |

## 6. HR, documents, and audit

| ID | Scenario | Expected result |
|---|---|---|
| HR-01 | Sales user requests payroll line by ID | Denied |
| HR-02 | HR user attempts payroll approval outside authorized duty | Denied |
| HR-03 | Manager reads sensitive disciplinary note outside reporting scope | Denied |
| DOC-01 | Anonymous user requests a document object URL | Denied |
| DOC-02 | Authenticated user requests another company's private object | Denied |
| DOC-03 | Authorized user receives short-lived signed download for permitted object | Allowed until expiry only |
| DOC-04 | Database metadata points to object outside the row's tenant scope | Rejected/hidden |
| DOC-05 | Object upload succeeds but metadata write fails | Retry/cleanup workflow prevents orphaned public file |
| AUD-01 | Ordinary client attempts to modify/delete audit history | Denied |
| AUD-02 | Every high-risk write records actor, timestamp, company, action, and correlation ID | Auditable record exists |

## 7. Persistence / smoke test

For each module that is enabled:
1. Create a uniquely named test record using a non-production test account.
2. Confirm the database write succeeds and returns a stable record ID.
3. Reload the browser and sign in again.
4. Confirm the record is still present and correctly scoped.
5. Sign in as the other company and verify the record is invisible.
6. Attempt an unauthorized direct API operation and verify rejection.
7. Remove test data using an approved test cleanup path, not by deleting production records.

Modules remain disabled until their complete create/read/update/approval/post/reversal flows pass.

## 8. Evidence record template

For each test, record: test ID, environment, branch/commit, role, company, table/RPC/object, action, expected result, observed result, timestamp, pass/fail, evidence reference, and follow-up issue.

**Execution note:** these are planned tests. No real browser, provisioned users, application tables, or RLS policies have been exercised yet.


## 8. Release candidate fixture-sanitization tests

| ID | Scenario | Expected result |
|---|---|---|
| REL-01 | Release candidate is built from reviewed source | Staging entry and reviewed source match before sanitization |
| REL-02 | Known embedded module seed collections are present in review source | Release build empties them explicitly; unknown seed-count changes fail the build |
| REL-03 | Enterprise master-data, stock, and payroll examples exist in review source | Release build replaces those example collections with empty collections |
| REL-04 | Release artifact contains preview admin, sample customer/supplier/employee/stock data, hard-coded email, or public document URL helper | Build/test fails |
| REL-05 | Release config is copied from staging config | Production mode remains false and Supabase URL/key placeholders remain blank |


## First-slice proforma test expansion (2026-10-24)
The disposable PostgreSQL smoke suite now explicitly exercises:
- PRIME cannot SELECT a BlackRock proforma row under RLS, even when querying the table directly.
- BlackRock cannot create a PRIME proforma by calling the public RPC directly.
- Inactive and terminated profiles are rejected by the trusted write function.
- String-valued `"NaN"` cannot be supplied as an item price or VAT rate; JSON-native types are checked before financial casts.
- Negative quantities are rejected, while valid VAT-inclusive calculations and concurrent unique numbering still pass.
These tests validate only the first-slice proforma draft in an ephemeral PostgreSQL service. They do not substitute for a real Supabase Auth/JWT, Data API exposure, or browser test, and they do not authorize applying the draft to the live project.
