# BOKAN ERP V6.7 — Database Contract Inventory (Draft)

Reviewed: 2026-10-21  
Branch: `deploy/secure-staging`  
Source: `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`

**Status:** design inventory only. This document is not executable SQL. No database schema has been applied.

## Confirmed Supabase state

Read-only checks on 2026-10-21 found no public application tables and no recorded migrations in project `kafiwnuynjemufnankvi`. The Security Advisor reports one warning: leaked-password protection is disabled. Its remediation is documented at https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.

Supabase's current API security guidance explains that database grants and RLS are separate layers and both must be deliberately configured: https://supabase.com/docs/guides/api/securing-your-api.

## A. Tables referenced by the application

The source directly references these 41 tables. This is a verified name inventory, not proof that each table should be created independently.

### Legacy application model
- `profiles` — identity-linked profile, role, department, company code, active status, termination status. Auth bridge selects: `id, full_name, role, department, company_code, active, terminated_at`.
- `companies` — issuer/company master; reads `code, legal_name, brand_name, tin, address, phone, proforma_title_color, active`.
- `company_bank_accounts` — issuer bank details; reads `id, company_code, bank_name, account_number, branch_name, account_purpose, display_order, active`. Current save routine deletes then reinserts all bank rows for a company; this needs safer audited writes and least-privilege controls.
- `proformas` — commercial proforma records and version snapshots. Current production bridge writes:
  `company_code, proforma_no, root_proforma_id, version_no, document_action, customer_name, customer_tin, customer_address, customer_phone, contact_person, proforma_date, vat_rate, subtotal_before_vat, discount_percent, discount_amount, vat_amount, withholding_enabled, withholding_rate, withholding_threshold, withholding_amount, grand_total, net_payable, company_tin_snapshot, bank_accounts_snapshot, items, notes, terms, status, created_by, updated_by`.
  Proforma history is created as new rows with increasing version number. Required: unique numbering rules, foreign keys, check constraints, immutable snapshots, server-side financial validation, and concurrency-safe numbering.
- `custom_terms` — commercial term options; current use includes `category, label, created_by`.
- `customers` — legacy customer master; also used with `customer_logs`.
- `customer_logs` — customer interaction and sales activity; fields referenced include `customer_id, sales_rep, deal_value, units_sold, product_type, status, created_at`.
- `customer_billings` — customer billing records; writes include `billing_no, customer, address, billing_date, deliveries, vat_percent, notes, subtotal, vat_amount, total, created_by` (exact full payload and all reads need a second pass).
- `sales_targets` — sales goals and commission; references include `period, employee, created_by` and configurable commission/flat-rate fields.
- `employees` — legacy employee records.
- `leave_requests` — legacy leave requests; references include `employee_name, leave_type, start_date, end_date, days, reason, created_by, status`.
- `performance_reviews` — legacy performance review; references include employee/reviewer names, review date, improvement notes, goals, created_by.
- `disciplinary_actions` — sensitive HR records.
- `expenses` — expense records; created/updated through data-entry workflows.
- `stock_entries` — inventory purchase/sale source entries; references include `entry_type, item_name, quantity, unit_price, total, created_by`.
- `stock_ledger` — inventory ledger; references include `entry_date` and stock movement/cost fields.
- `trip_plans` — staff travel; references include `employee_name, departure_date, return_date, destination, transportation_mode, purpose, product_type, planned_visits, notes, is_late_exception, late_explanation, created_by`.
- `per_diem_requests` — travel allowances; references include `trip_plan_id, employee_name, destination, total_requested, status, created_by`.
- `visit_reports` — sales field visits; includes employee/customer/date and late-explanation fields.
- `notifications` — in-app notices; current insert includes `type, message, meta, read, created_by`. Needs recipient/tenant scoping; global listing is unsafe as a design default.
- `documents` — repository metadata; current insert includes `category, title, file_path, file_url, uploaded_by` plus category-specific columns. Storage bucket policies and metadata policies must align.

### Newer modular model
- `bokan_customers` — newer CRM customer master; queried by `customer_name`; includes `assigned_salesperson_id` and `created_by` in current bridge.
- `bokan_customer_activities` — CRM activity records; current bridge sets `created_by, salesperson_id`.
- `bokan_customer_assignments` — reassignment audit; current bridge writes `customer_id, previous_salesperson_id, new_salesperson_id, reason, reassigned_by`.
- `bokan_salespeople` — sales identity/assignment; deactivation writes `active, departed_at`.
- `bokan_sales_opportunities` — sales pipeline opportunities; current bridge adds `created_by`.
- `bokan_employees` — newer HR employee model.
- `bokan_attendance_records` — attendance; current bridge inserts a payload.
- `bokan_leave_requests` — newer leave model.
- `bokan_performance_reviews` — newer performance review model.
- `bokan_payroll_runs` — payroll run header; highly sensitive.
- `bokan_payroll_lines` — payroll detail; highly sensitive.
- `bokan_payroll_approvals` — payroll approval records; highly sensitive.
- `bokan_shipments` — inbound logistics; bridge references `shipment_no, purchasing_entity, legal_owner_company_code, carrier, eta, status, factory_id, notes`.
- `bokan_delivery_orders` — delivery controls; bridge references `delivery_no, legal_owner_company_code, operational_owner_entity, warehouse_id, promised_delivery_date, delivery_status, customer_id, notes`.
- `bokan_journal_entries` — general ledger journal records.
- `bokan_ar_invoices` — accounts receivable invoices.
- `bokan_ar_receipts` — accounts receivable receipts.
- `bokan_ap_bills` — accounts payable bills.
- `bokan_ap_payments` — accounts payable payments.
- `bokan_fiscal_periods` — accounting periods; bridge filters by `company_id` and sorts by `period_start`.
- `bokan_finance_close_readiness` — referenced RPC, not a table. Called with `p_period_id`.
- `bokan_next_proforma_number` and `next_proforma_no` — referenced RPCs; choose one secure, concurrency-safe numbering function and remove legacy fallback once reconciled.

## B. Required architecture decisions before creating tables

1. **Choose canonical models.** Resolve legacy/new duplicates for customer CRM, employees, leave requests, and performance reviews. Do not create both models merely because both names exist in the source.
2. **Company ownership.** Decide a consistent legal-entity key for every company-owned row. Existing modules mix `company_code`, `company_id`, `legal_owner_company_code`, and `operational_owner_entity`. Use foreign keys to a company master where appropriate; validate allowed codes in the database.
3. **Profile provisioning.** `profiles.id` should reference `auth.users.id`. Normal users must not be able to change their own role, company code, active state, or termination state. Provision users through a controlled admin process.
4. **RLS matrix.** Define per-table read/insert/update/delete rules by role and company. HR/payroll, finance, bank accounts, documents, approvals, and audit data need distinct rules. Updates require both a row visibility rule and a check preventing reassignment to another company or user.
5. **Trusted writes.** Validate money totals, VAT-inclusive pricing, withholding thresholds, proforma version/numbering, accounting postings, payroll approvals, and inventory balances at a trusted database boundary. UI-calculated totals are not authoritative.
6. **Atomic operations.** Journal posting, receipt/payment posting, stock movements, bank-account changes, and customer assignment history should be transactional; avoid multi-step browser writes that can partially succeed.
7. **Audit and deletion.** Decide retention, soft-delete/void behavior, append-only history, who can reverse transactions, and audit columns before granting delete access.
8. **Documents and storage.** Align `documents` table RLS with the private Storage bucket. A URL in a row must not bypass authorization. Review current client-side file deletion and upload behavior.
9. **Local storage.** Some company settings, preferences, or business data remain in browser `localStorage`. Identify each key and move authoritative shared/company settings into secured database tables.
10. **Test plan.** Test anonymous access, PRIME vs BlackRock cross-tenant access, role escalation, inactive users, update-policy bypass, deleted/terminated users, and invalid financial values before any production switch.

## C. Proforma data rules to preserve

- Item prices are entered VAT-inclusive; totals must not add VAT on top.
- Discount applies according to the agreed proforma calculation.
- Withholding is 3% of VAT-inclusive Grand Total only when the total exceeds ETB 10,000, when enabled.
- Net payable = Grand Total minus withholding.
- Proforma version history must preserve company details, bank-account snapshot, terms, and delivery terms for the version created.
- Proforma numbering must be generated safely under concurrent use; a browser timestamp or client-generated number is not sufficient for production.

## D. Do not proceed to live DDL until

- Every write payload and select/join has been traced to actual required columns.
- The legacy/new canonical model decisions are signed off in this design.
- RLS policies and grants are drafted for each table and reviewed together.
- A migration can be tested and verified without exposing data.
- The hosted auth gate is corrected and the mock backend cannot be reached in any hosted configuration.

This file is a design artifact only. It does not create tables, change Auth settings, apply policies, or enable production mode.
