# Live Supabase Migration Source-Control Gap — 2026-10-26

## Verified state

The connected Supabase project `kafiwnuynjemufnankvi` reports 15 applied migration records. The default GitHub branch `main` contains 11 SQL migration files that correspond to the later applied records. Those 11 files have now been copied byte-for-byte into `deploy/secure-staging` so the review branch has the same source for the currently tracked sales, purchasing, payment and inventory changes.

The following four applied records have no corresponding SQL file in the repository's Git history (a path-specific GitHub commit search returned no file history):

| Applied version | Applied name | Source status |
|---|---|---|
| `20261025065910` | `initial_multi_company_sales_foundation` | SQL source not found in repository history |
| `20261025072547` | `revoke_unauthenticated_erp_table_access` | SQL source not found in repository history |
| `20261025124247` | `add_missing_foreign_key_indexes` | SQL source not found in repository history |
| `20261025124312` | `atomic_sales_document_creation` | SQL source not found in repository history |

The database migration-list API returns the applied version/name records, not the SQL bodies. These four files must not be fabricated and represented as the exact original historical migrations.

## Safety correction

The earlier file `supabase/migrations/20261024000000_core_proforma_mvp.sql` was a disposable-test candidate, not an applied migration. It defines a conflicting `companies/profiles` model and must not be run against the existing `companies/company_memberships` foundation.

It has been moved to `supabase/candidates/core_proforma_mvp.sql`. Disposable PostgreSQL tests point to this candidate path. The executable migration directory is reserved for migrations compatible with the actual project history.

## Required reconciliation before further live schema changes

1. Keep the 11 recovered source files byte-for-byte aligned with `main` and the current live migration records.
2. Recover the four missing SQL bodies from an authoritative backup/export or the original execution environment if available.
3. If exact originals cannot be recovered, create a clearly labeled **current-schema baseline snapshot** from live catalog definitions; do not backdate or pretend the snapshot is the original migration.
4. Compare the baseline against live tables, constraints, indexes, RLS policies, grants, views, triggers, and function definitions.
5. Only after parity is documented, add new forward-only migrations against the existing `companies.id/code` and `company_memberships` model.
6. Do not apply the old Proforma candidate. It must be redesigned additively to use the live company UUID/membership model and real Supabase Auth.
7. Do not mark a migration applied merely to make the version list appear complete; the database and source history must agree.

## Automated guard

`scripts/test-live-migration-source-parity.mjs` checks that the 11 tracked applied migrations exist, that the four missing records are documented, and that the incompatible Proforma candidate is not located in `supabase/migrations/`. This guards source layout and inventory accuracy; it does not prove the historical SQL matches the live database.
