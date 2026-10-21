# BOKAN ERP V6.7 — Production Blockers Found in Source Review

Review date: 2026-10-21
Scope: static review of `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`. This is not a penetration test. No database or deployment changes were made.

## Stop-ship findings

### 1. Legacy mock backend still exists in the HTML
The file includes a mock client that returns a fixed demo user, accepts sign-in without validating credentials, and reports successful mock writes. The configuration guard is helpful, but the hosted application must be proven to fail closed across every entry point and script before production. A browser-side flag is not a substitute for database security.

### 2. Multiple data paths use company-unscoped legacy tables
Examples include `customers`, `customer_logs`, `employees`, `leave_requests`, `performance_reviews`, `expenses`, `sales_targets`, `stock_entries`, `stock_ledger`, `trip_plans`, `visit_reports`, `documents`, and `proformas`. Some newer BOKAN production bridges use company-aware concepts, but the main UI also accesses legacy models. A schema that only secures the newer tables would leave the legacy paths unresolved.

### 3. Authorization checks are inconsistent
Some production bridges call a session check, while several legacy form handlers directly query `sb` and rely on UI role visibility. UI visibility is not authorization. Every query and mutation must be restricted by RLS and database-side ownership/company rules.

### 4. Sensitive writes need consistent error handling and database-side constraints
Several handlers call update/delete or secondary writes without consistently checking returned errors. The UI may continue as if a change worked, and related writes may partially succeed. Production work should use checked responses and database transactions/RPCs where multiple changes must succeed together.

### 5. Document storage currently requests public URLs
The document repository calls `getPublicUrl(path)`. HR, finance, and corporate documents may be sensitive. Production must use a private bucket with narrowly scoped Storage policies and authenticated downloads (e.g. signed URLs) unless every stored file is explicitly approved for public access. Do not assume a database row policy protects the underlying object.

### 6. Proforma numbering and legacy fallback require consolidation
The source references both `bokan_next_proforma_number` and `next_proforma_no`, plus a legacy save path. Production must use one concurrency-safe, company-specific numbering function and one canonical save path, with authorization and uniqueness enforced in PostgreSQL.

### 7. Company and user identity must be database-enforced
Profile data includes role, department, company code, active state, and termination state. These fields cannot be user-editable authorization sources. Company-specific settings and bank-account changes need company-scoped policies, restricted admin rights, and auditability.

## Work required before creating production tables/policies

1. Inventory every active query, mutation payload, join, RPC and Storage path; identify which modules are still legacy.
2. Decide the canonical model for each overlapping domain, including customers/CRM, employees, leave, performance reviews and proformas.
3. Add explicit company ownership and foreign keys where the business model requires them; define legitimate cross-company group reporting separately from transactional access.
4. Define protected membership/profile data and a server-side role/permission model. Never authorize from localStorage or editable user metadata.
5. Design RLS and SQL grants for each canonical table, including SELECT policies needed for UPDATE and both USING/WITH CHECK on updates.
6. Design private Storage policies for documents and replace public URL use for confidential files.
7. Make critical multi-step workflows transactional and make all failures visible.
8. Write negative tests for anonymous access, cross-company reads/writes, role escalation, inactive users, document access, approval separation and duplicate numbering.
9. Only then prepare a migration and test it in a non-production environment before enabling production mode.

## Current state
- No SQL schema, RLS policy, Storage policy, or migration has been applied.
- No production deployment has been made.
- Keep production mode disabled and Supabase configuration placeholders blank until the blockers above are resolved.


## Follow-up fix: hosted startup gate (2026-10-21)
The main `boot()` path previously assigned a preview administrator unconditionally, and its error handler could unhide the app. Commit `63ad0c2e321f5544d7d84475b1b0dc75be5b4126` changes this so preview identity is assigned only on local file/localhost review, hosted startup keeps the app hidden pending the production auth bridge, and startup errors hide the app rather than reveal it. Static pattern checks passed after the change. This still requires browser testing on both local preview and hosted configuration; it does not clear the other blockers in this report.


## Follow-up fix: document storage safety guard (2026-10-21)
The repository upload and delete handlers used public Storage URL flow. Production uploads and deletions are now temporarily blocked until a private bucket, aligned Storage policies, and authorized download flow are implemented. Local preview remains available. This reduces the risk of accidentally exposing confidential documents but intentionally leaves the production document repository unavailable until the secure replacement is completed.


## Follow-up fix: role administration and bank-account writes (2026-10-21)
- Role change UI now validates the requested role against the supported list, permits production requests only for the authenticated admin role, and handles database errors instead of silently ignoring them. This is a UI guard only; database RLS/grants must enforce administrator-only updates to protected profile columns.
- Production bank-account replacement is temporarily blocked because the current implementation deletes all company bank-account rows before inserting replacements, which can leave a company with no bank accounts if the insert fails. Re-enable only after an atomic, audited server/database workflow is implemented and tested.


## Follow-up fix: issuer identity settings (2026-10-21)
Production issuer TIN and address/phone save handlers now reject requests from roles other than admin/accounting. This is a user-interface safeguard only; RLS/grants must enforce company scope and role authorization. Changes still need audit logging and database policy validation before production enablement.


## Critical follow-up: legacy server API gate was force-hidden (2026-10-21)
Source review found a second legacy production adapter using `API='/api'`, with `DEV_BYPASS=true` and CSS that force-hid its sign-in gate. If the API bootstrap failed, the catch handler hid the gate and exposed the app. The adapter now enables bypass only on local file/localhost review, removes the force-hide CSS, and fails closed on hosted origins. The hosted message makes clear that server-backed modules require a configured application API.

**Architecture blocker:** the current Cloudflare static hosting path does not itself provide this `/api` backend. This change intentionally blocks the hosted legacy adapter until the API is implemented or those modules are migrated to a secure Supabase-backed path. Do not merge/deploy as a functioning production app yet.
