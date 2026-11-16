# BOKAN ERP V7 — Supabase environment

## Isolated project

- Project: BOKAN ERP V7
- Supabase project reference: `thfzvtltmaieesjulggr`
- Region: `eu-central-2`
- API URL: `https://thfzvtltmaieesjulggr.supabase.co`
- Organization: BlackRock Investment
- Plan at creation: Free
- Quoted recurring project cost at creation: USD 0/month

This is a separate Supabase project. Do not point V7 at the legacy BOKAN ERP project
(`kafiwnuynjemufnankvi`) or the WeHaul project.

## Applied migrations

The following V7-only migrations were applied and verified:

1. `v7_initial_schema`
2. `v7_role_policies`
3. `v7_tenant_integrity`
4. `v7_product_purchase_workflows`
5. `v7_audit_triggers`
6. `v7_foreign_key_performance_indexes`
7. `v7_transaction_landed_costs`
8. `v7_private_document_storage`
9. `v7_harden_document_storage_policies`
10. `v7_document_upload_cleanup_policy`
11. `v7_landed_cost_reference_index`
12. `v7_data_entry_purchasing_permissions`
13. `v7_database_approval_guards`
14. `v7_customer_specific_sales_prices`
15. `v7_customer_price_fk_index`
16. `v7_creator_rollback_policies`
17. `v7_membership_administration`
18. `v7_membership_admin_rpc`
19. `v7_admin_role_assignment`
20. `v7_consolidated_delete_policies`
21. `v7_lock_commercial_status_transitions`
22. `v7_approval_attribution_guard`
23. `v7_purchase_request_approval_guard`
24. `v7_purchase_request_conversion`
25. `v7_supplier_specific_purchase_prices`
26. `v7_audit_read_restriction`
27. `v7_recipient_notifications`
28. `v7_submission_notifications`
29. `v7_notification_fk_indexes`
30. `v7_company_settings_permissions`
31. `v7_invited_first_owner_bootstrap`
32. `v7_private_first_owner_bootstrap`
33. `v7_blackrock_only_company_details_and_admin`

Verification at setup:
- 20 public application tables
- Row Level Security enabled on all 20 tables
- 74 RLS policies
- 0 unindexed foreign keys (including landed-cost, customer/supplier pricing and notification references)
- Private document bucket with company-folder Storage RLS and 10 MB file limit
- Transaction-level landed-cost fields with same-company purchase-line references
- Database triggers enforce manager-only sales and purchase-order approvals
- Customer-specific sales price history with company-safe foreign keys
- Creator-scoped cleanup policies for incomplete first-save transactions
- Company-scoped membership management with owner/admin boundaries
- Admins can assign other admins; owner role remains owner-controlled
- Consolidated safe-delete policies avoid duplicate permissive-policy warnings
- Commercial status transitions and approval attribution are database-guarded
- Purchase requests have manager-only approval enforcement and controlled conversion to linked supplier orders
- Supplier-specific purchase prices have same-company references and lookup indexes
- Company owners/admins can update company names and VAT basis points
- Audit history is readable only by company management roles
- Recipient-only in-app notifications are generated for approvals, submissions and purchase-request conversion
- 0 operational business rows, stock records, or imported historical data. Live Auth state is one invited and email-confirmed administrator account; this is not a business-data import.
- Current advisor state (2026-11-16): one security warning (`auth_leaked_password_protection`, disabled); 46 informational unused-index notices; no health findings.

The performance advisor subsequently reports newly created indexes as unused because
the database has no live workload yet. Reassess after real application traffic rather
than removing those indexes prematurely.

## Vercel preview configuration

The Vercel project `bokan-erp-v7` has the following preview-only environment
variables scoped to branch `rebuild/bokan-erp-v7`:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

The publishable key is a public client credential, not a service-role secret.
No service-role key is configured in the browser environment.

Production environment variables are intentionally not configured until V7 has
passed review and a production release is explicitly prepared.

## Supabase Auth redirect configuration for review

Before inviting the first owner, open Supabase Dashboard → Authentication → URL Configuration:

- Set the review **Site URL** to
  `https://bokan-erp-v7-git-rebuild-bokan-erp-v7-bokanplc-3642.vercel.app`
- Add this exact callback URL to the redirect allowlist:
  `https://bokan-erp-v7-git-rebuild-bokan-erp-v7-bokanplc-3642.vercel.app/auth/callback`
- Keep the production domain `https://bokan-erp-v7.vercel.app/auth/callback` in the allowlist for the later release, but do not change the Site URL to production until the production deployment exists.

The Vercel review project currently has SSO protection enabled for all deployments. Only authorized Vercel team members can open this review URL. Do not distribute it to employees as their live ERP link. When V7 is approved for production, configure the production URL, review deployment protection, and use a production-targeted deployment.

## Current onboarding state and safe future procedure

**Do not follow the historical two-company bootstrap procedure.** It is obsolete and conflicts with the owner's V7-only scope.

Live state verified 2026-11-16:
- One company only: BlackRock Investment PLC.
- Currency ETB; VAT 15%.
- One invited, email-confirmed Auth account with one active `admin` membership.
- No employee accounts and zero operational business rows.
- Company/bootstrap setup is already complete. Do not rerun bootstrap or create Prime Investment Group.

For future employee onboarding, create/invite accounts only after explicit owner approval for the specific invitations. The Administration membership flow accepts existing V7 Auth accounts; it does not create credentials or send invitations. Assign only the approved sales and data-entry roles under the single BlackRock company.

The first-owner bootstrap RPC remains a historical implementation detail and must not be used again against this initialized project. No legacy users or business data are to be imported. Add fresh reconciled business data only when the user supplies it.

## Legacy V6.7

Keep the old project intact until V7 is fully reviewed, authenticated, deployed,
and the user confirms that the new system is ready. Then take a final backup/export,
verify any retention obligations, and only then consider deleting the old project.
