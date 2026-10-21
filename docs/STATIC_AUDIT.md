# BOKAN ERP V6.7 static audit

Audit date: 2026-10-21  
Source inspected locally: `BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`  
This report describes a static review only; it is not a production certification.

## Checks completed
- Extracted 35 non-empty inline JavaScript blocks.
- Ran Node.js syntax validation against each extracted inline script: **0 syntax failures**.
- Identified 41 distinct table names referenced by `.from(...)` calls.
- Found 96 `localStorage` references in the HTML source.
- Found mock-backend fallback logic (`makeMockSupabase()`).
- Found no literal `service_role` or `SUPABASE_SERVICE_ROLE_KEY` strings in the inspected HTML.

## What these results mean
Passing JavaScript syntax checks confirms only that the extracted scripts parse. It does not prove that the page renders correctly, all features work, or the database schema/policies match the application.

The mock-backend fallback means production hosting must inject valid configuration and must not let staff mistake in-memory/demo data for saved ERP records. The many local-storage references also require a module-by-module review to distinguish harmless UI preferences from business data that must be stored centrally and protected by RLS.

## Remaining work before live use
1. Commit the exact reviewed full ERP HTML source into this private staging branch.
2. Perform runtime/browser smoke tests for navigation, auth, roles, company switching, proforma calculations, history, and key workflows.
3. Trace all 41 table names to actual field-level queries and writes; remove obsolete duplicate models where appropriate.
4. Design and review the SQL schema, indexes, constraints, and RLS policies before applying migrations.
5. Test that unauthenticated users and users from the other company cannot read or alter protected records.
6. Confirm production startup fails closed when required configuration or session is absent.
7. Test a manual export/restore workflow compatible with the current Free plan.

## Current state
No application database schema changes have been made. The repository's `main` branch remains untouched. The staging branch contains deployment documentation, not yet the full ERP source code.
