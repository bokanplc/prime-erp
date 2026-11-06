# BOKAN ERP — Release Scope Decision (2026-11-06)

## Owner decision

The owner has directed that the full HR section be put on hold for the current release. BlackRock Investment PLC currently needs the sales operation, not a full HR/payroll system.

## Current release scope

Prioritize:
- Authentication, company membership and role-based access for BlackRock staff
- Customer master data and full CRM sales workflow
- Sales documents and controlled approval/posting
- Purchasing documents and controlled receipt
- A single canonical inventory/stock ledger, including opening stock
- Direct sales costs and landed costs
- Profitability reporting (landed gross profit and profit after direct sales costs)
- Essential administrator controls and the employee-readable company policy handbook

Do not make full HR functionality a release requirement:
- Employee lifecycle / HR CRUD
- Attendance
- Leave management
- Performance reviews
- Disciplinary actions
- Payroll

HR source code and database tables are not to be destructively deleted. Keep the section disabled or outside the production module allowlist until the owner asks to resume it.

## Accounting boundary

Customer receipts and supplier payments remain in Peachtree and must not be introduced as ERP payment-entry requirements.

## Release authorization and safety gate

The owner has authorized changing `main` and deploying production after this scope decision. This authorization does not waive the release safety checks. Do not enable hosted production mode or promote a deployment while sales/purchase persistence, stock posting, company-scoped authorization, real staff sign-in, and browser smoke tests remain unverified.

The current `deploy/secure-staging` and `main` refs have diverged (918 commits ahead / 46 behind at the 2026-11-06 checkpoint). Do not force-update `main` or merge the histories blindly. Reconcile the branch history and inspect the exact target tree first.

## Immediate engineering order

1. Implement and test sales-document creation, approval and atomic stock issue.
2. Implement and test purchase-document creation, approval/receiving and atomic stock receipt.
3. Reconcile legacy stock screens with canonical `stock_movements`, including opening stock.
4. Verify CRM with real sales-team memberships and browser tests.
5. Verify direct transaction-cost capture and profitability calculations.
6. Verify policy handbook read access for staff and admin-only printing.
7. Run end-to-end tests for admin, sales and data-entry roles; only then enable the reviewed production tabs and deploy the tested commit.

No historical transaction, inventory, user, or financial data is changed by this scope decision.
