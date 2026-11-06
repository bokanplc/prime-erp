# Public API privilege hardening — 2026-11-06

Applied to Supabase project `kafiwnuynjemufnankvi` as migration
`20261106151808_harden_public_api_privileges`.

## Findings addressed

- Removed `TRUNCATE`, `REFERENCES`, `TRIGGER`, and PostgreSQL 17 `MAINTAIN`
  privileges from the browser `authenticated` role on existing public tables.
  These privileges are not required for ordinary application CRUD; in particular,
  `TRUNCATE` is not governed by row-level security.
- Removed any existing public-table privileges from `anon`.
- Removed broad default table and sequence grants for `anon` and
  `authenticated` for objects created by the migration owner.
- Removed implicit execution of all public-schema functions from `PUBLIC`,
  `anon`, and `authenticated`, then restored authenticated execution only for
  the four public RPCs currently called directly by the hosted source:
  `bokan_save_company_proforma_settings`, `bokan_save_proforma`,
  `bokan_reassign_customer_owner`, and `post_journal_entry`.
- Removed broad default function execution for future public functions created by
  the migration owner.

## Verification

A read-only post-migration check confirmed:
- No table privileges remain for `anon`.
- `authenticated` retains only SELECT/INSERT/UPDATE/DELETE table privileges;
  RLS policies continue to constrain row access.
- The four listed RPCs remain executable by `authenticated`; no public-schema
  function remains executable by `anon`.
- Default privileges owned by `postgres` no longer grant browser-role access.

## Remaining caution

The Supabase-managed `supabase_admin` role has a separate default-privilege
record; it was not modified by this migration. New application migrations should
continue to run as `postgres` and explicitly grant only required access. This
hardening does not substitute for browser-level role tests or full module
workflow tests.


## Follow-up: privileged RPC implementation isolation — 2026-11-06

Applied as migration `20261106151937_move_privileged_rpc_implementations_private`.

- Moved the two authenticated `SECURITY DEFINER` implementations
  (`bokan_reassign_customer_owner` and `post_journal_entry`) into the non-exposed
  `private` schema.
- Replaced their public entry points with `SECURITY INVOKER` SQL wrappers, retaining
  the existing RPC names and argument signatures used by the application.
- Kept the authenticated-only execution grants on the wrappers and private
  implementations; anonymous execution remains denied.
- Verified both public wrappers are no longer SECURITY DEFINER and the private
  implementations remain SECURITY DEFINER with their existing in-function
  authentication, company-role and payload checks.
- Re-ran the Supabase Security Advisor: the two signed-in SECURITY DEFINER
  warnings are cleared. The remaining warning is that leaked-password protection
  is disabled in Supabase Auth; this is an Auth dashboard setting, not a database
  migration.
