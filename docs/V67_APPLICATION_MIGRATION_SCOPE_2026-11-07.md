# BOKAN ERP V6.7 — Application Migration Scope Reset (2026-11-07)

## Owner direction

The owner has directed that the current work prioritize migration of the full V6.7 application and its standard application functionality, not reconciliation or import of any existing business dataset. The owner will later provide a new, fully reconciled dataset for stock, customers, and other business records.

This direction supersedes earlier work plans that treated historical stock, sales, purchase, or customer reconciliation as a prerequisite for application migration.

## Current application scope

Migrate and verify the full V6.7 application interface and its standard non-stock operational workflows, including:

- Authentication, active company context, user memberships, and role-based navigation.
- CRM customer management, leads/opportunities, calls, visits, follow-ups, reminders, customer history, and salesperson activity reporting.
- Sales pipeline and sales-order draft creation (document creation only; no stock issue/posting).
- Proforma workflow and customer-facing document generation.
- Company administration, employee access controls, document repository, and policy handbook.
- Transaction-related expenses and other approved operational cost-entry screens, without inventory valuation or cost-of-goods calculations.
- Finance and management reporting screens where they can be migrated as read-only or operational workflows without depending on stock posting, customer receipts, supplier payments, or unverified opening balances.
- Supply/logistics planning screens where they do not receive purchase stock or issue sales stock.

## Explicitly parked — do not implement or use as migration blockers now

The owner explicitly asked to leave the following areas aside until fresh reconciled data is supplied and a later instruction reopens them:

1. Historical stock information, balances, and stock-swap reconciliation.
2. Sales stock posting / stock issue.
3. Purchase receiving / stock receipt.
4. Inventory costing, valuation, COGS, and landed-cost allocation.
5. Import, cleanup, reconciliation, or validation of old customer, sales, purchase, stock, and financial records.

Do not spend further migration effort reconciling these datasets. Do not use current database quantities or historical documents as acceptance criteria for the application work. Do not expose stock posting, purchase receiving, or costing actions in the first application release.

## HR decision

HR remains deferred from the initial release. Preserve its source and schema where needed for future work, but do not include HR in the initial production tab allowlist.

## Data handling

- Existing live records are preserved as-is; this scope reset is not an instruction to truncate or delete the database.
- Do not import, transform, reconcile, or certify the old records.
- Keep the new data import as a separate future phase after the owner supplies the reconciled dataset.
- Application acceptance should use disposable test fixtures and rollback-only tests, not business records.

## Release acceptance

A non-stock application module is eligible when its screen is connected to the correct company-scoped Supabase tables/RPCs, permissions are enforced server-side, production mode cannot fall back to localStorage/demo data, and authenticated role tests pass.

The app must retain the complete V6.7 interface. A module can remain disabled from production until its own app workflow is verified, but it must not be replaced by a reduced sample app.

No production release or main-branch promotion is authorized by this scope note. The existing user authorization to replace main remains subject to the app's functional and security gates.
