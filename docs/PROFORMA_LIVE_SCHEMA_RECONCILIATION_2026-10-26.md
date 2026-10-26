# Proforma ↔ Live Supabase Contract Reconciliation — 2026-10-26

## Status and safety boundary

This is a source-to-live-catalog reconciliation only. It does not change the live database, authentication, data, or deployment settings. It is not permission to enable production mode.

Compared:
- Full staging source: staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html (blob SHA 4b923e9d750ca0bbe92c3fadb65936965a50bacb, 804,678 characters).
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

## Recommended additive staging design (not yet implemented)

1. **Issuer settings:** add a company-ID-keyed settings table for the Proforma-only issuer fields missing from companies (TIN, address, phone, brand/title presentation). Keep companies.name canonical; do not add a parallel company registry.
2. **Bank accounts:** add company_bank_accounts with company_id uuid references public.companies(id), display ordering, active flag, and least-privilege reads. Save an immutable JSON snapshot of displayed bank details on each Proforma so later account changes do not rewrite issued documents.
3. **Proformas:** add a company-ID-keyed proformas table with unique numbering per company and version, a root/version relationship, customer snapshots, item/term JSON arrays (or normalized child tables if line-item reporting is required), VAT/discount/withholding totals, status, created/updated actor IDs and timestamps. Add database constraints for JSON array/object shapes, nonnegative amounts, rate bounds, and unique (company_id, proforma_no, version_no).
4. **One atomic RPC:** implement only public.bokan_save_proforma(text, uuid, jsonb) as the supported save path. It must resolve p_company to the live company UUID, require auth.uid(), verify active membership and role, lock the company-scoped number/version sequence, validate the entire payload, calculate totals server-side, and insert/update a version transactionally. It must return the complete row shape the source mapper needs. Do not keep a separate client-number-then-insert path.
5. **Read policy:** SELECT on Proformas must require active membership for the same company. Avoid direct client INSERT/UPDATE/DELETE grants if the atomic RPC is the only write path. Use a SECURITY INVOKER RPC where feasible and fully qualify objects with an empty search_path; if a privileged function is proven necessary, isolate it in the private schema and review every authorization check.
6. **Issuer lookup:** change source queries to use existing companies.code/name/is_active and a joined/settings table, rather than selecting nonexistent columns from companies. Use company_id for all database relations, with company code only as a user-facing key.
7. **Math and business rules:** before finalizing database checks, compare the actual calculateBokanProformaTotals implementation with the intended VAT-inclusive pricing, discount order, rounding, withholding threshold and net-payable behavior. The existing candidate's arithmetic constraints must not be reused until this comparison is complete.
8. **Version semantics:** verify whether the UI action “update” means create a new immutable version or mutate a draft. The current UI copy says “without overwriting the original”; implement and test that promise. Ensure a supplied existing ID cannot cross company boundaries and cannot silently change a different Proforma number.
9. **Tests:** run in disposable PostgreSQL first: schema install, authorized save/read, unauthenticated rejection, inactive membership rejection, wrong-company ID rejection, role denial, malformed payload rejection, totals/rounding, immutable revision lineage, duplicate/concurrent numbering, and rollback after a forced item validation failure. Then run browser tests with non-production Auth sessions. No live migration until those pass.

## Release gate

The current production Proforma path is **not ready**. At minimum, issuer loading, bank-account loading, Proforma read/save, safe numbering, and company isolation are unresolved. Keep production flags and enabled-module lists off. This report intentionally does not include a live migration or an unverified SQL patch.
