# BOKAN Sales Operations & CRM (Prototype)

## What is this?
An independent sales workflow prototype intended to become a secure employee-facing CRM. This is separate from BOKAN ERP V6.7/V7 and must not integrate stock/accounting.

## Current prototype
- `index.html`: browser-only UI for command center, leads, cold calling, field sales, proforma request queue, maker placeholder, tasks, and reporting.
- Local browser storage only. It is NOT multi-user and must not be used for real business records.
- No seed/demo customer, stock, or price data.

## Key requirement
**Junior Sales requests proforma → Supervisor assigns → Authorized Senior creates it using the original V6.7 Proforma Maker → Junior tracks request status.** The source V6.7 request and maker forms must be extracted with original styling, fields, calculations, buttons, print behavior, and terms. The maker remains a placeholder until exact extraction/integration is finished.

## Progress
- [x] Scope approved
- [x] Isolated branch and draft PR created
- [x] First browser-only interface committed
- [x] Initial forms/toggles corrected and duplicate-ID check passed
- [x] V6.7 source audit identified request/maker sections and key functions
- [x] Draft database schema added (not deployed)
- [ ] Extract and verify original V6.7 proforma request/maker
- [ ] Remove Sales workspace from V6.7 (feature branch only)
- [ ] Complete server-backed authorization, multi-user storage and role/team permissions
- [ ] Daily submission + supervisor approvals + audit logging
- [ ] Reminders/notifications and performance reporting
- [ ] Test security and workflow, build, and deploy
- [ ] Invite employees (after owner approval)

## GitHub work
- Branch: `feature/v67-remove-sales-crm-extraction`
- Draft PR: https://github.com/bokanplc/prime-erp/pull/9

## Database draft
`supabase/schema-draft.sql` contains proposed organization, membership, leads, call logs, visits, tasks, proforma request/items, daily submissions, and audit log tables. It is not applied; role/team RLS policies still require review and tests.

## Hosting
Separate Vercel project and separate Supabase project are planned. A Supabase project creation cost quote was returned as **$0/month** for the only connected organization (BlackRock Investment). The project has not been created because organization placement must be confirmed. No production deployment or employee invitations have been made.
