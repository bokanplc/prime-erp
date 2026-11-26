# BOKAN Standalone Sales Operations & CRM — Build Specification

## Product separation
- Remove the Sales Department workspace from BOKAN ERP V6.7 in a dedicated feature branch only.
- Do not modify `main`, production, V7, or deploy without separate explicit release approval.
- Build a new, independent **BOKAN Sales Operations & CRM** app with its own authentication, database, roles, and deployment. Do not couple it to ERP stock, accounting, or payment records.
- Start with clean CRM data; do not import or invent customer records, prices, stock levels, or sales history.

## Proforma request → senior-created proforma workflow (required)
Keep the V6.7 Proforma Request and Proforma Maker workflow as a first-class feature of the standalone CRM. The existing V6.7 proforma request form and maker are the approved reference for the UI, layout, fonts, fields, calculations, and button behavior. Extract them without redesigning them; preserve functionality and styling unless a necessary integration change is documented and approved.

1. **Junior sales / cold-call reps:** Create and submit a proforma request. They do not create or issue proformas. Requests include customer, requested items/specifications, quantity, request notes, requested date/deadline, and any other fields present in the V6.7 request form. Missing data must be flagged, not guessed.
2. **Request queue:** Requests move through Submitted, In Review, Needs Information, In Progress, Completed, and Cancelled. Record requester, timestamps, owner, and status history. Supervisors can assign/route requests and return incomplete requests with comments.
3. **Senior sales / authorized proforma makers:** Review the request, clarify missing details, and create the proforma using the preserved V6.7 Proforma Maker. Only authorized seniors/makers can create, edit, finalize, or issue proformas.
4. **Linkage:** A completed proforma is linked to the originating request, customer/prospect record, senior maker, and revision history. The junior requester can view status and the completed proforma according to permission.
5. **Controls:** Do not invent prices, customer names, product quantities, specifications, or stock information. Use only entered/approved data. Preserve a clear audit trail for request, assignment, revisions, maker, and completion.
6. **Reporting:** Show request backlog, age, status, pending information, assigned senior, turnaround time, and completed proformas by day/week/team. Include overdue alerts.

## Core roles
- Owner / Admin
- Sales Manager
- Supervisor / Team Leader
- Junior Sales / Cold-Call
- Senior Sales / Field Sales / Proforma Maker

## CRM modules
- Sales Command Center and daily KPI summary
- Leads & customer prospect profiles
- Pipeline stages (exact): New Lead, Contacted, Quoted, Negotiating, Closed Won, Closed Lost
- Cold Calling workspace
- Field Sales and territory/visit planning
- Proforma Request inbox and request tracking
- Proforma Maker (preserved V6.7 functionality)
- Task assignments and reminders
- Daily submissions, supervisor review, approvals/returns
- Performance scorecards, conversion analytics, leaderboard
- Coaching notes, customer activity timeline, audit history

## Daily accountability
Every task/activity category must show Assigned / Completed / Pending. Keep Junior/Cold-Call and Senior/Field Sales separate. Daily review must report completion percentage against assigned work, closed sales and new quotations, stalled deals and required follow-ups, overdue activities, and supervisor approval items. Percentages must be based on actual entered records, never fabricated examples.

## Daily submission and approval flow
Manager sets targets → supervisor assigns daily work → reps log activity and submit daily report → supervisor reviews, approves, or returns for revision with comments → manager sees consolidated results. Preserve the submission/review history.

## Product-interest categories
Plywood, timber, morale/moralo, common nails, construction materials, and other building supplies. Product interest only; this is not stock integration.

## Build and release safety
- Use isolated branches and separate app infrastructure.
- No demo data.
- No employee accounts, invitations, credentials, public deployment, or production cutover without explicit authorization.
- Implement and verify each module before calling the app complete.
