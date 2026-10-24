# BOKAN ERP V6.7 — Owner Decisions Needed Before Production

This list is for the next review session. No response is needed while work continues. No production change should be made by guessing these items.

## 1. Main architecture decision

**Recommended: Route A — consolidate login and business data on Supabase Auth + PostgreSQL/RLS, with Cloudflare Pages serving the static UI.** This avoids maintaining two identity systems and an arbitrary localStorage-sync API. It requires migrating the legacy modules that currently expect `/api/*`.

Alternative: Route B — retain a separate authenticated application API for the legacy modules. This requires building and maintaining the backend, session handling, password reset/rate limiting, data authorization, migrations, audit and recovery. Static hosting alone is not enough.

No paid plan or upgrade is assumed for either route.

## 2. User accounts and access scope

- Should every employee sign in using their own email and password? Supabase Auth naturally supports this; the current legacy gate asks for a username and depends on an API that does not exist in the staged repository.
- Which named administrators are authorized for both PRIME and BlackRock? Do not share one generic admin login.
- Can any employees work for both companies, or is membership always one company per person?
- Who should be able to prepare and approve payroll, post journals/payments, maintain issuer TIN/bank details, and administer roles?

## 3. Data migration and canonical modules

- Are the old browser localStorage customer/proforma/control records real business data that must be preserved, or are they review/demo data? Do not bulk-import without this distinction.
- For customers/CRM, employees, leave requests, and performance reviews, which current screens/workflows must be retained? The source references both legacy and newer models.
- Should users be able to view their own HR records, and which managers may see direct-report information?
- Which document categories exist, and which roles/companies can view each category?

## 4. Issuer contact detail verification

- The current source repeats the same phone number in both PRIME and BlackRock issuer settings. BlackRock's known phone is 978 23 48 20, but PRIME's official phone has not been confirmed from the current project records. Confirm PRIME's number before finalizing issuer details; do not silently reuse BlackRock's number on PRIME documents.

## 5. Operational recovery

- Before real transactions are entered, agree who owns manual exports and document recovery under the existing free-plan constraints.
- Confirm which non-production test users can be created for cross-company and role testing.

## Current safe position

The default branch is unchanged, the PR remains draft-only, production mode is disabled, Supabase has no application schema/migrations, and no live deployment has been made. Work that does not depend on these decisions can continue: source analysis, tests, schema drafts, security guards, and CI.


## Existing Supabase security-advisor warning
The read-only security advisor still reports Leaked Password Protection Disabled (auth_leaked_password_protection). The current connected workflow has no supported Auth-settings action to toggle it. Before production accounts are invited, enable the protection in Supabase Auth settings if available on the existing plan, then re-run the security advisor. Do not compensate by lowering password requirements.


## Proforma withholding rule confirmation (2026-10-24)
The current UI treats withholding as automatic at 3% when the VAT-inclusive Grand Total is strictly above ETB 10,000. The trusted database draft now enforces that same fixed rate/threshold and rejects direct RPC payloads that try to disable or alter them. The UI still needs a final accounting review of discount/VAT treatment; do not use live documents until that tax treatment is confirmed.
