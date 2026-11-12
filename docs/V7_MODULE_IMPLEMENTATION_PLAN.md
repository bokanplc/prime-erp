# BOKAN ERP V7 — module implementation plan

## Product boundary

This is a fresh application, not a data migration. The V7 database must contain zero imported business records. Do not read from or write to the legacy Supabase project. Do not copy legacy users, company rows, customers, suppliers, products, prices, stock, purchases, sales, proformas, balances, documents or audit events. The legacy app may only be consulted as a workflow reference for already-approved requirements.

BlackRock Investment PLC is the sole V7 company. Its company row and owner membership must be created through the secure, invitation-gated bootstrap procedure; no other company or tenant is to be provisioned.

## Build order

1. Platform foundation: environment validation, secure session handling, protected routes, company context, role model, audit primitives and health checks.
2. CRM: customer and contact directory, lead capture, pipeline stages, calls, visits, reminders, timeline and salesperson activity.
3. Sales: quotations/proformas, price selection, discount controls, 15% VAT calculation/presentation, approvals and document lifecycle.
4. Purchasing: supplier directory, purchase requests, purchase orders and purchase price capture.
5. Direct costs and profitability: transaction-linked transport, loading and miscellaneous costs; landed gross profit and profit after direct sales costs.
6. Logistics: delivery planning, dispatch milestones, delivery evidence and exceptions.
7. Documents and notifications: access-controlled attachments, version metadata, reminders and notifications.
8. Reports: sales activity, pipeline, margins, direct costs and salesperson performance.
9. Administration and release: user invitations, company memberships, role assignments, audit review, backup/restore and end-to-end verification.

## Explicit exclusions

- HR and payroll are deferred.
- Customer receipts and supplier payments are excluded; Peachtree remains the payment/accounting system.
- No general ledger, journal, bank reconciliation or replacement accounting.
- No historical stock posting, purchase receiving, opening stock, stock reconciliation, inventory valuation or inventory costing.
- No demo or fixture business data in any hosted environment.

## Security and data acceptance gates

- Every business row is scoped to a company and protected by RLS.
- Company membership and role checks are derived from trusted database records, never client-supplied values or user-editable metadata.
- Every exposed table has RLS enabled and explicit least-privilege policies.
- UPDATE policies have both USING and WITH CHECK; views use security_invoker where supported.
- Service-role/secret keys remain server-only.
- No route exposes business data before authentication and company authorization succeed.
- Audit events are append-only for application roles.
- Empty states remain empty; do not manufacture counts, sample totals or demo transactions.
- Verify tenant isolation with two distinct test identities before any employee release.
- Keep V7 database resources isolated from the legacy project. Do not reset, truncate or modify the legacy project.

## Release gates

Preview deployment only until build/lint checks, authentication, authorization, tenant isolation, persistence, auditability, document access, backup/restore and full workflow tests pass. Production promotion and employee distribution require explicit owner approval after evidence is presented.
