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

## 6. Proforma tax and numbering confirmation

- The current UI applies 3% withholding automatically when VAT-inclusive Grand Total is strictly greater than ETB 10,000. The database candidate now enforces this server-side. Confirm this rule is correct for the company's use cases before production documents are issued.
- The current discount formula displays pre-discount VAT and subtracts the discount from the VAT-inclusive total. Ask the company's accountant to confirm this VAT/discount treatment for Ethiopian tax compliance.
- Confirm the generated Proforma number convention (customer-name prefix plus a four-digit sequence) is acceptable, or provide the official format to preserve.

## Current safe position

The default branch remains untouched, PR #1 remains draft-only, production mode and both module allowlists are disabled/empty, and no live deployment has been made. The current live Supabase project has 12 public application tables and 15 applied migration records. Eleven migration SQL bodies have been recovered into staging; four applied records remain unrecovered. The UUID-company Proforma candidate and its new PostgreSQL 17 test suite are not applied to live Supabase, and the latest CI result has not been verified. Work that does not depend on owner decisions can continue: source analysis, tests, schema candidates, security guards, and CI.


## Existing Supabase security-advisor warning
The read-only security advisor still reports Leaked Password Protection Disabled (auth_leaked_password_protection). The current connected workflow has no supported Auth-settings action to toggle it. Before production accounts are invited, enable the protection in Supabase Auth settings if available on the existing plan, then re-run the security advisor. Do not compensate by lowering password requirements.


## Proforma withholding rule confirmation (2026-10-24)
The current UI treats withholding as automatic at 3% when the VAT-inclusive Grand Total is strictly above ETB 10,000. The trusted database draft now enforces that same fixed rate/threshold and rejects direct RPC payloads that try to disable or alter them. The UI still needs a final accounting review of discount/VAT treatment; do not use live documents until that tax treatment is confirmed.
