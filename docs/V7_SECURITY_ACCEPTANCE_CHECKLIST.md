# V7 security acceptance checklist

Do not enable employee access until every applicable item has evidence.

## Environment isolation
- [ ] A new Supabase project has been provisioned specifically for V7.
- [ ] Its project reference has been checked and is not the legacy project.
- [ ] Vercel Preview and Production environment variables point only to the isolated V7 project.
- [ ] No service-role key is exposed to browser code or public NEXT_PUBLIC variables.
- [ ] No legacy storage bucket, database schema, backup or export is connected.

## Authentication and company authorization
- [ ] Email/password sign-in is verified against V7 Auth.
- [ ] Session refresh works after navigation and expiry.
- [ ] Callback URLs are restricted to approved V7 domains.
- [ ] Company records and memberships are created only by a separately approved bootstrap.
- [ ] Every user can read only their own membership and memberships they are authorized to administer.
- [ ] Company membership and role are checked from database records, not user metadata or browser-supplied role claims.
- [ ] Company switch requests are revalidated against active membership on the server.

## Tenant isolation
- [ ] Every company-owned table has RLS enabled and forced.
- [ ] Every business query includes company scope and relies on RLS as the enforcement boundary.
- [ ] Composite foreign keys prevent cross-company references.
- [ ] Two-company tests prove one company's user cannot read, insert, update, delete or reference another company's records.
- [ ] Viewer role has no write permissions.
- [ ] Audit events are append-only to application roles.
- [ ] Storage object policies enforce company membership and private buckets.

## Business workflow correctness
- [ ] CRM lead, call, visit, reminder and customer history flows are tested.
- [ ] Sales quotations/proformas and 15% VAT calculations are reconciled against approved test cases.
- [ ] Purchasing price capture and approvals are tested.
- [ ] Direct cost categories are limited to transportation, loading and miscellaneous transaction costs.
- [ ] Landed gross profit and profit after direct costs are reconciled against independent calculations.
- [ ] No customer receipt or supplier payment workflow exists.
- [ ] No general ledger, journal, bank reconciliation, stock posting, purchase receiving or inventory valuation is enabled.
- [ ] HR/payroll remains deferred.

## Operations and release
- [ ] Document upload/download is private and access-checked.
- [ ] Audit logging is complete for critical writes and approvals.
- [ ] Backups and restore are tested in the V7 environment.
- [ ] Error handling and empty states are tested without fabricated business records.
- [ ] Automated CI passes.
- [ ] Preview has been reviewed by the owner.
- [ ] Production promotion and employee invitations are separately approved.


## Evidence reconciliation — 2026-11-16

The following infrastructure evidence has been observed in the isolated V7 project and latest CI run; it does not close the browser-acceptance items above:

- Supabase project `thfzvtltmaieesjulggr` reports `ACTIVE_HEALTHY`.
- 33 migrations applied; 20 public base tables; RLS enabled and forced on all 20.
- One BlackRock Investment PLC company and one active `admin` membership. Auth privacy counts: 1 user, 1 invited, 1 email-confirmed, 1 with a recorded sign-in.
- GitHub Actions run `43229514035` passed both `database-migration-smoke` and `verify` for commit `9226aa9c6cabf9d54ce5dfcc6cc41e4019f0f869`.
- Vercel Preview deployment `dpl_9YM5y2PhjBF8Jh7ZpJAkoxRapFx5` is `READY` from the same commit.
- Supabase security advisor reports one warning: leaked-password protection disabled. Performance advisor reports 46 informational unused-index notices. Health advisor reports no findings.

Still open: authenticated browser login/session/navigation/persistence/document-access tests; real sales and data-entry role-path acceptance; owner Preview review; backup/restore evidence. Automated disposable-database tenant-isolation tests do not require or authorize creating a second live company. Keep all open items unchecked until their evidence is recorded.
