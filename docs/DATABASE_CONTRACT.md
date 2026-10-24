# BOKAN ERP database contract — staging audit

Status: discovery only. This is **not** a migration and must not be applied as SQL.

## Findings from the V6.7 review source
The frontend references the following table names. Some may be legacy/overlapping models; references alone do not prove the intended columns, constraints, or relationships.

### Identity and organization
- `profiles`
- `companies`
- `company_bank_accounts`
- `custom_terms`

### Proforma, customers, and sales
- `proformas`
- `customers`
- `customer_logs`
- `customer_billings`
- `bokan_customers`
- `bokan_customer_activities`
- `bokan_customer_assignments`
- `bokan_salespeople`
- `bokan_sales_opportunities`
- `sales_targets`
- `visit_reports`

### Accounting and finance
- `expenses`
- `bokan_ap_bills`
- `bokan_ap_payments`
- `bokan_ar_invoices`
- `bokan_ar_receipts`
- `bokan_fiscal_periods`
- `bokan_journal_entries`

### Inventory and logistics
- `stock_entries`
- `stock_ledger`
- `bokan_delivery_orders`
- `bokan_shipments`
- `trip_plans`

### HR and payroll
- `employees`
- `attendance_records`
- `bokan_attendance_records`
- `leave_requests`
- `bokan_leave_requests`
- `per_diem_requests`
- `disciplinary_actions`
- `performance_reviews`
- `bokan_performance_reviews`
- `bokan_payroll_approvals`
- `bokan_payroll_lines`
- `bokan_payroll_runs`

### Documents and notifications
- `documents`
- `notifications`

## Deployment blockers to resolve before creating tables
1. **Schema contract:** trace every read/insert/update/delete to determine exact columns, required fields, foreign keys, uniqueness, and status values. The duplicate-looking legacy and `bokan_*` table names must be reconciled deliberately rather than blindly creating both.
2. **Tenant isolation:** enforce company scope in the database, not just the UI. PRIME Investment Group PLC and BlackRock Investment PLC must not see each other's records unless a documented cross-company role permits it.
3. **Role authorization:** derive role and department from a protected profile/admin-controlled source. Never trust user-editable metadata for authorization.
4. **RLS:** enable row-level security on every exposed application table. Define least-privilege SELECT/INSERT/UPDATE/DELETE policies per table and operation; verify UPDATE has both SELECT visibility and `WITH CHECK` protection.
5. **Auth bootstrap:** the app expects a `profiles` row and rejects users without an active BOKAN profile. Document a safe first-admin bootstrap before enforcing this gate.
6. **Production mode:** production must fail closed when Supabase URL/key/configuration is missing. A preview/mock backend must never silently accept production work.
7. **Migrations and recovery:** commit reviewed SQL migration files in this private repository before applying schema changes. On the Free plan, don't assume PITR or automatic backups; make a manual export before risky changes where possible.

## Verified project state (read-only audit)
- Supabase project ref: `kafiwnuynjemufnankvi`
- `public` application tables reported: zero
- Recorded migrations reported: zero
- No database schema changes were made during this audit.

## Validation checklist
- [ ] Full source committed to a private staging branch
- [ ] Every table operation and field mapped
- [ ] SQL migration reviewed and stored in version control
- [ ] RLS policies tested as anon, authenticated, both company users, and admin
- [ ] Cross-company read/write attempts denied
- [ ] Auth/profile bootstrap tested
- [ ] Production mode cannot fall back to mock data
- [ ] Proforma totals and VAT/withholding rules tested
- [ ] Syntax and browser smoke tests pass
- [ ] Recovery/export procedure documented and tested


## Proforma display arithmetic follow-up (2026-10-24)
The current Proforma print layout displays subtotal before VAT, VAT, a separate discount row, then grand total. The trusted save draft and UI have been aligned so:
- `subtotal_before_vat` is extracted from the original VAT-inclusive line total before discount.
- `vat_amount` is the original VAT-inclusive gross less that subtotal.
- `discount_amount` is the percentage discount on the VAT-inclusive gross.
- `grand_total = subtotal_before_vat + vat_amount - discount_amount`.
- Withholding remains 3% of final VAT-inclusive grand total only when it is strictly greater than ETB 10,000.

This is the requested presentation arithmetic. The final tax treatment of discounts should be confirmed by the business's Ethiopian tax/accounting adviser before live invoice use. The schema remains a draft and has not been applied to Supabase.
