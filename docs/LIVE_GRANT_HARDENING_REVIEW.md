# Live ERP table-grant hardening review — 2026-10-26

## Evidence from the connected Supabase project

Read-only catalog checks found RLS enabled on all 12 public tables and no RLS-bypassing public views (both current views use `security_invoker=true`). The private membership helpers require `auth.uid()`, use an empty search path, and are not executable by `anon` or `PUBLIC`.

However, `has_table_privilege('authenticated', table, 'TRUNCATE')`, `TRIGGER`, and `REFERENCES` returned true for every inspected public table and the reconciliation view. Authenticated also has ordinary DML table grants on most tables; `supplier_payments` deliberately does not have table-level UPDATE, reflecting narrower column permissions. RLS does not protect `TRUNCATE`, so this grant surface is broader than a browser ERP needs even though the standard Supabase Data API does not expose arbitrary SQL statements.

## Proposed narrow change

`supabase/candidates/revoke_non_dml_authenticated_privileges.sql` revokes only `TRUNCATE`, `TRIGGER`, and `REFERENCES` from `PUBLIC`, `anon`, and `authenticated` on all current public tables/views. It intentionally preserves existing SELECT/INSERT/UPDATE/DELETE and column-level grants, avoiding an accidental reset of the supplier-payment column restrictions.

The disposable PostgreSQL test first simulates the broad grants, applies the candidate, and verifies:
- all three unnecessary privileges are gone;
- existing ordinary DML grants remain;
- the test covers both a table and a `security_invoker` view.

## Why it is not applied to the connected project yet

The live project has 15 migration records, but four historical SQL bodies are missing from repository history. This is a source-of-truth gap. The candidate is deliberately not in `supabase/migrations/` and has not been applied to live Supabase. First recover or formally baseline the missing migration history, then create a proper versioned migration using the repository's approved migration workflow and verify it on a disposable copy of the live schema. Do not use this candidate to change the live database until that review is complete.
