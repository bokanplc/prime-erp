# BOKAN ERP V6.7 — Implementation Roadmap and Effort Estimate

**Estimate date:** 2026-10-23  
**Basis:** static review of the staged single-file source, current design inventories, and read-only Supabase checks.  
**Important:** these are engineering effort estimates, not calendar guarantees. No production schema or browser acceptance test has yet been completed.

## Executive estimate

For one experienced full-stack engineer working full-time, with business decisions answered promptly:

- **Technical proof of a secure hosted login + one end-to-end module:** approximately **5–10 working days** after the architecture decision and test users are available.
- **A limited pilot (authentication, company separation, proformas, and essential customer/CRM workflows):** approximately **2–4 weeks**.
- **Broad V6.7 production release across finance, inventory/operations, HR/payroll, documents, approvals, reporting, and legacy module migration:** approximately **6–10+ weeks**, followed by business acceptance and security testing. The source is a large monolithic HTML app and has 41 direct table references, overlapping models, and localStorage-backed modules, so the upper end or longer may be necessary.

These ranges assume no major redesign and no new features. They assume the current free-plan constraint remains in place. A developer cannot safely make the final release date certain until a browser runtime test and the full module dependency map are complete.

## Phase plan

| Phase | Work | Estimated effort | Exit condition |
|---|---|---:|---|
| 0. Architecture / source audit | Confirm Supabase Auth + RLS as the single identity path; finish source-to-field/payload inventory; decide which legacy modules are in pilot | 1–3 days | Approved scope and canonical model decisions |
| 1. Foundation | Companies, profiles, membership/role model, audit fields, grants, RLS, migration files, test identities | 3–7 days | Cross-company direct API tests pass |
| 2. Pilot persistence | Proformas/versioning/numbering, customer master, CRM activity/follow-up; calculations and save/error states | 4–8 days | Create/edit/read/version tests pass for both companies |
| 3. Legacy migration | Replace or isolate localStorage business records and missing `/api/*` adapter per module; exclude seeds unless verified | 5–12 days | No business-critical module depends on fake login or unpersisted local state |
| 4. Finance / operations | Journals, AR/AP, fiscal periods, stock, procurement, shipment/delivery, trusted transaction workflows | 7–15 days | Totals, lifecycle, concurrency, reversals, permissions and audit tests pass |
| 5. HR / payroll / documents | Employee, attendance, leave, reviews, payroll approvals; private Storage and signed downloads | 5–12 days | Sensitive-data access matrix and document tests pass |
| 6. Verification / recovery | Browser/device tests, RLS bypass tests, reconciliation, export/restore rehearsal, performance/accessibility review, release checklist | 4–8 days | Signed business acceptance and no critical/high findings |

Phases can overlap after the data model is stable, so the sum of all rows is not a direct calendar forecast. The 6–10+ week broad-release estimate includes expected integration and rework.

## Critical path

1. **Choose the single identity architecture.** Recommended: Supabase Auth + PostgreSQL/RLS, static UI hosted separately. The missing legacy `/api/*` adapter must be migrated or implemented safely.
2. **Resolve membership and role scope.** A single `profiles.company_code` may not support people authorized for both PRIME and BlackRock; this needs an explicit decision before schema creation.
3. **Choose canonical models.** At minimum, resolve customers/CRM, employees, leave, performance reviews, proforma numbering/versioning, and finance transaction ownership.
4. **Create schema and policies in a testable sequence.** Every exposed table needs least-privilege grants, RLS, tenant checks, update checks, and appropriate constraints.
5. **Implement and verify high-risk writes.** Numbering, journal posting, invoices/receipts, bills/payments, payroll approvals, stock movements, bank details and documents must not depend on client-side values alone.
6. **Test in a real browser with test identities for both companies.** Passing source syntax checks is not a substitute for runtime or persistence tests.
7. **Reconcile and accept data.** Determine whether browser stores are real or demo; export, map, deduplicate and validate only confirmed business records.
8. **Deploy only after all gates pass.** Keep production mode disabled until then.

## What can be done without owner input

- Source audit and static checks.
- Canonical field/payload mapping and draft schema review.
- RLS policy design and unauthorized-access test cases.
- Legacy storage key inventory and dry-run migration tooling.
- Test harnesses and deployment documentation.
- Non-production code cleanup that preserves the current fail-closed behavior.

## What should not be guessed

- Whether browser/localStorage seed data is real operational data.
- Whether employees can have roles in both companies.
- Who can approve payroll, post journals/payments, change company legal/bank details, or administer users.
- Whether all legacy modules must be included in the first pilot.
- Legal/accounting rules not explicitly encoded or confirmed.

## Free-plan constraint

No paid service or upgrade is assumed. Keep schema migration files, scheduled manual exports where feasible, and a tested restore procedure. Confirm actual free-plan quotas and backup limitations before entering real business records. Do not treat a successful export as a tested recovery until a restore has been rehearsed.

## Current stop-ship items

- Live Supabase currently has a 12-table public sales/procurement/inventory foundation, all with RLS enabled, 42 table policies, no direct `anon` table grants, 15 recorded migrations, and no deployed Edge Functions. The full ERP remains incomplete; see `docs/LIVE_SCHEMA_ACCESS_AUDIT_2026-10-26.md` and `docs/LIVE_SCHEMA_RECONCILIATION_2026-10-26.md`.
- Leaked-password protection remains disabled according to the Security Advisor; the available project tools do not expose a safe Auth-setting toggle.
- Legacy `/api/*` endpoints are missing.
- Canonical legacy/new models and membership-scoped authorization are unresolved.
- Private Storage/signed downloads are not implemented.
- Real browser, Auth, RLS, persistence, reconciliation and restore tests have not run.
- Production config remains disabled and blank.

## Release principle

Do not promise a fixed launch date based on static source review alone. After Phase 0 and the first complete pilot module, replace these ranges with a measured schedule based on actual build/test throughput and the remaining module list.
