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


## Updated live inventory — 2026-10-31

The connected Supabase migration ledger now reports **30 applied migration records**. The executable source directory contains **23 tracked applied migration SQL files**. Seven applied migration bodies remain absent from the repository and are deliberately not reconstructed as if they were exact originals:

| Applied version | Applied migration | Source status |
|---|---|---|
| 20261025065910 | initial_multi_company_sales_foundation | Historical SQL body unrecovered |
| 20261025072547 | revoke_unauthenticated_erp_table_access | Historical SQL body unrecovered |
| 20261025124247 | add_missing_foreign_key_indexes | Historical SQL body unrecovered |
| 20261025124312 | atomic_sales_document_creation | Historical SQL body unrecovered |
| 20261031080833 | add_company_scoped_proforma_foundation | Applied SQL body not present in current migration directory |
| 20261031081151 | add_company_scoped_crm_foundation | Applied SQL body not present in current migration directory |
| 20261031081422 | restrict_crm_assignment_writes_to_rpc | Applied SQL body not present in current migration directory |

The four historical bodies remain intentionally benched per the migration instruction. The three newer CRM/Proforma bodies also remain a source-control reconciliation task. Do not fabricate or backdate any of these seven bodies. Current forward migrations are source-controlled; the source-parity guard explicitly checks the 23 available executable files and documents all seven gaps. This is not full historical migration parity.

## New forward migrations recorded

- 20261031113713 — company-scoped general ledger foundation.
- 20261031114856 — atomic journal posting and reversal workflow.
- 20261031115029 — reversal sequencing correction so the reversal link is recorded while the new journal is still draft, before immutable posting.

The current database ledger includes these migrations. The reversal sequencing correction was tested in a rollback-only authenticated transaction. No business journals or accounts were seeded.


## General Ledger access hardening — 2026-10-31

- 20261031122850 — direct table privileges on ledger accounts, fiscal periods, journal entries and journal lines restricted: anonymous access revoked; authenticated users retain read access only. Ledger writes must pass through validated RPC workflows.
- Live privilege verification confirmed no anon SELECT/INSERT on these four tables and no authenticated INSERT/UPDATE/DELETE; authenticated SELECT remains enabled under company-scoped RLS.
- The migration source-parity guard now tracks this 20th available applied migration. This does not close the seven historical/source-control gaps listed above.


## CRM bridge and permission alignment — 2026-10-31

- 20261031124029 — grants now match the existing CRM row-level workflow policies: authenticated users may update opportunities and after-sales tasks subject to owner/manager checks; customer hard-delete is revoked; activity and assignment histories remain append-only; assignment writes remain RPC-only.
- Live privilege verification: authenticated users have SELECT/INSERT on CRM activities, SELECT/INSERT/UPDATE on opportunities and after-sales tasks, and no UPDATE/DELETE on activities or assignment history. Customers remain company-scoped; authenticated hard-delete is revoked.
- The full V6.7 CRM bridge and Sales customer workflow now target canonical `customers`, `crm_customer_assignments`, `crm_assignment_events`, `crm_activities`, `crm_opportunities`, and `crm_after_sales_tasks` tables. It uses the selected authenticated company UUID, the manager-only reassignment RPC, and append-only activity history. It no longer writes to legacy `bokan_*` tables.
- The V6.7 Sales customer directory, customer form submission, activity timeline, weekly follow-up list and CRM coverage dashboard are now wired to the canonical API. Opportunity and after-sales task CRUD endpoints are available in the bridge but still need dedicated screen controls. CRM API/UI wiring is not the same as complete screen acceptance: no live authenticated browser test has been performed, and CRM remains gated from production activation until authenticated browser tests and the opportunity/after-sales task controls are complete.


## Supply & Logistics source-document linkage — 2026-10-31

- 20261031124815 — inbound shipments now optionally link to a purchase order using a composite `(company_id, purchase_document_id)` foreign key. A trigger rejects cross-company, non-purchase-order, cancelled or void sources.
- Delivery orders now optionally link to an approved/posted sales order or invoice through a composite `(company_id, sales_document_id)` foreign key. The trigger rejects cross-company or ineligible source documents and copies the canonical customer name into the delivery snapshot when available.
- Both link columns are nullable to preserve existing records and allow planning before source-document association. No business records were imported or altered.
- The Supply & Logistics bridge exposes eligible purchase-order and delivery-source selectors and includes the source IDs in live reads. The V6.7 inbound and delivery forms now expose eligible source-document selectors; authenticated browser persistence and cross-company denial tests remain pending.
- The migration source-parity guard now tracks 23 available applied SQL bodies. Seven historical/CRM/Proforma applied bodies remain unrecovered; this is still not full historical source parity.


- 20261031125430 — tightened the shipment-to-purchase-order trigger so draft purchase orders cannot be attached to inbound shipment plans. Only submitted/approved/active receiving or payment statuses are eligible, matching the V6.7 source selector.


- 20261031125554 — customer reassignment now validates that the selected owner is an active `sales` or `staff` member of the same company. The V6.7 reassignment selector applies the same role filter; managers still perform the reassignment through the authorized RPC with a required reason.
