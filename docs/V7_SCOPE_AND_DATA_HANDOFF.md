# BOKAN ERP V7 scope and data handoff

## Data policy

- No customer, supplier, product, stock, transaction, opening-balance, or employee dataset is imported as part of the V7 application build.
- Existing V6.7 business records are not copied, reconciled, transformed, or used as V7 opening balances.
- The owner will provide the newly reconciled dataset after the V7 application is ready and the data-import process is agreed.
- Application code, schema definitions, migrations, tests, and empty templates are not business data imports.
- Never seed production with demo fixtures. Preview fixtures are confined to a no-credentials, noindex review build.

## V7 operating scope

- Company context and employee access for the approved companies.
- Full sales CRM: customer directory, assignments, leads/opportunities, pipeline, calls/visits, reminders, customer history, and salesperson performance.
- Sales documents and proforma workflows, with 15% VAT default and explicit VAT-exempt selection.
- Product catalogue, purchasing and purchase prices, stock control and sales prices. New stock/product data is loaded only after owner handoff.
- Direct transaction costs: landed purchase costs, direct sales costs, and separately classified general overhead.
- Profitability: landed gross profit, gross margin, profit after direct sales costs, and the corresponding margin percentage.
- Company documents and operating controls needed by sales and data-entry teams.

## Explicitly parked or excluded

- HR/payroll/attendance/leave/performance/disciplinary workflows.
- Accounting ledgers, journals, trial balance, financial statements, bank/cash management, customer receipts, supplier payments, collections, and payment reconciliation. Peachtree remains the accounting/payment system.
- Historical V6.7 stock posting, purchase receiving, inventory-costing records, customer/supplier records, and opening balances. Standard stock functionality remains part of the application; historical records do not.
- Customer billing/receivable balances from the old system.
- Legacy Cloudflare Pages API routes. V7 uses the reviewed Vercel + Supabase architecture; legacy API compatibility is not a release prerequisite unless a live V7 feature is proven to depend on one.

## Release and onboarding sequence

1. Finish source-code module contracts and non-destructive automated tests.
2. Complete schema/RLS/security review without loading business data.
3. Verify owner, manager, salesperson, and data-entry access using a secure authenticated test session.
4. Release the approved V7 application to Vercel only after release gates pass.
5. Invite the four initial employees and confirm company access.
6. Receive the owner's fresh reconciled dataset, review its mapping, then import it under a separate approved data-onboarding procedure.
