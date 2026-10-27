# Proforma ↔ Live Supabase Contract Reconciliation — 2026-10-26

## Status and safety boundary

This is a source-to-live-catalog reconciliation only. It does not change the live database, authentication, data, or deployment settings. It is not permission to enable production mode.

Compared:
- Full staging source: staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html (blob SHA bf98ae0b540629e88bc9ce27f6ef846bd9f4603e, 805,662 characters).
- Connected live Supabase public schema and current public RPC catalog.
- Older candidate supabase/candidates/core_proforma_mvp.sql, which is design reference only and is not compatible with the current tenant identity model as written.

## Confirmed contract breaks

| Full source expects | Live project currently has | Result |
|---|---|---|
| public.proformas | No proformas table | Saved Proforma list, production retrieval and direct legacy insert cannot work against current schema. |
| public.company_bank_accounts | No company_bank_accounts table | Production issuer-bank load fails. |
| companies.legal_name, tin, address, phone, proforma_title_color | companies.id uuid, code text, name text, is_active boolean, timestamps | Issuer lookup selects nonexistent columns and fails. |
| bokan_save_proforma(p_company text, p_existing_id uuid, p_payload jsonb) | No matching public RPC | Production atomic save cannot work. |
| next_proforma_no() | No matching public RPC | Legacy numbering fallback is unavailable; random client-side numbering is not safe for production. |
| proformas.company_code / company_code-based filtering | Tenant identity is company_id uuid referencing companies.id, with access via company_memberships | Candidate schema/RPC must translate company code to UUID and authorize via membership. Never trust client-supplied company code alone. |

The source's bokanProdMapProformaRow reads company_code, proforma_no, version_no, root_proforma_id, customer_name, customer_tin, customer_address, customer_phone, contact_person, proforma_date, discount_percent, delivery_terms, withholding_enabled, withholding_rate, withholding_threshold, bank_accounts_snapshot, items, terms, grand_total, and net_payable. These are not columns on any live table today.

The original source mapper omitted vatPct from the returned form object; the staging source now restores it from the saved vat_rate. The new static contract test checks this round-trip, but a browser test is still required.

The source save payload carries:
- Customer: customer, tin, address, phone, contactPerson, date
- Pricing: vatPct, discountPct, items
- Terms: delivery, notes, terms
- Withholding: withholdingEnabled, withholdingRate, withholdingThreshold

The source's captured line items use description, spec, qty, and unit_price. This is a distinct shape from the existing sales-document item contract (description, quantity, unit_price, tax_rate, etc.). A Proforma adapter must validate and normalize these fields explicitly rather than assume they match sales line items.

## Existing live model that must be preserved

- public.companies is UUID-keyed. Current business codes are stored in code, with the display name in name.
- public.company_memberships links user_id to company_id and carries an active flag and role.
- Private helpers private.has_company_membership(uuid) and private.can_manage_company(uuid) are already used by existing RPCs. Keep them private and use the established authorization pattern.
- Existing public.sales_documents can represent document types including proforma, but it does not contain the issuer bank snapshots, terms, customer TIN/address/phone snapshots, proforma version lineage, or withholding fields required by this UI. It should not be overloaded as a drop-in replacement without a deliberate product decision.

## Staging implementation now committed (candidate only)

1. Added `supabase/candidates/live_company_proforma.sql`, an additive candidate using the live UUID-keyed companies and active company-membership model, company-scoped issuer settings and bank accounts, Proforma revision history, RLS, a single atomic save RPC, and an authorized issuer-settings RPC. It remains under `supabase/candidates/` and is **not** an executable migration or applied to live Supabase.
2. Updated both full source and staging entry to read `companies.id/code/name/is_active`, load issuer fields from `company_proforma_settings`, scope bank accounts by `company_id`, save issuer fields through the settings RPC, and include `company_id` when creating production custom terms.
3. Fixed the saved Proforma mapper to restore `vatPct` from `vat_rate`, and added `scripts/test-live-company-proforma-contract.mjs` to the staging GitHub Actions workflow.
4. The candidate's save function uses active company membership, server-side VAT-inclusive calculations, company-scoped advisory locks, immutable new revision rows, snapshots of active bank accounts, and no direct Proforma DML grants to the browser. The withholding behavior remains fixed at 3% above ETB 10,000 as currently encoded in the UI; this is a business rule that still needs owner/accounting confirmation.
5. Added disposable PostgreSQL tests at `scripts/test-live-company-proforma-postgres.sql` and `scripts/test-live-company-proforma-concurrency.sh`, and wired them into a separate PostgreSQL 17 GitHub Actions job. Static contract checks were also added to the existing workflow. These checks have been authored and source-verified here, but no GitHub Actions success result is available in the current connector response, so they are **not yet reported as passed**.
6. **Still required before any executable migration:** confirm CI actually passes, fix any SQL/runtime failures, populate issuer settings and bank accounts only from owner-verified details, and complete browser end-to-end tests. No live migration has been applied.

## Release gate

The current production Proforma path is **not ready**. The candidate and UI contract patch are committed to staging, but the candidate has not been run against PostgreSQL and the new GitHub Actions result has not been verified. Keep production flags and enabled-module lists off. Do not apply the candidate to live Supabase yet.
