# Supabase Data API exposure — upcoming default change

**Reviewed:** 2026-10-24  
**Applies to:** BOKAN ERP first-slice schema draft; no live settings or schema changed.

Supabase's current official API security guide explains that table/function grants and RLS are separate controls. Grants determine whether a role can reach an object through the Data API; RLS controls which rows are visible or writable once the object is reachable. New table exposure defaults are changing on **2026-10-30**, according to the official [Supabase changelog](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically).

## BOKAN ERP implementation rule

Do not rely on automatic default grants or assume that a table is available just because it exists in PostgreSQL.

For every future migration:
1. Explicitly revoke unwanted privileges from \`PUBLIC\`, \`anon\`, and \`authenticated\`.
2. Explicitly grant only the operations required by the intended client role.
3. Enable RLS on every exposed application table and create table-specific policies.
4. Restrict \`EXECUTE\` on every function; remove default \`PUBLIC\` execution when not intended.
5. Keep internal schemas such as \`private\` out of the exposed-schema list.
6. After migration, verify the actual exposed-schema configuration, grants, RLS flags, and function privileges in the project.
7. Test through the real Data API with anonymous, PRIME, BlackRock, and authorized administrator test accounts.

## Current draft status

The un-applied \`docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql\` explicitly revokes table privileges from \`anon\` and \`authenticated\`, then grants narrowly scoped privileges; it enables RLS on its five tables and revokes public function execution for the trusted proforma functions. This still needs a project-specific exposure/grant review before application. Do not apply it to the current project until test evidence and architecture decisions are approved.

## Current project check

Read-only checks on 2026-10-24 still report zero public application tables and zero migrations. No Supabase database or settings changes were made in this review.
