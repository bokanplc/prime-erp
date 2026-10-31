# BOKAN ERP V6.7 — CRM UI to live schema reconciliation
**Date:** 2026-10-31
**Branch:** `deploy/secure-staging`
**Status:** additive schema compatibility applied; UI remains review-only pending authenticated integration.

## What the existing V6.7 Sales CRM expects

The actual Sales CRM form and reports use the following browser-side data contract:

- Customer: `customer_name`, `contact_person`, `location`, `phone`, `phones[]`, `email`, `current_status`, `lead_source`, and an assigned representative.
- Interaction: `customer_id`, `sales_rep`, `status`, `activity_type`, `notes`, `customer_feedback`, `deal_value`, `units_sold`, `product_type`, `next_action_type`, `next_action_date`, `escalated`, `escalate_reason`, and `escalate_note`.
- Existing UI also expects profile names for representative labels, and currently exposes deletion of interaction logs and direct customer reassignment.

## Live canonical schema

The live canonical customer master is `public.customers`, with `id`, `company_id`, `name`, `contact_person`, `phone`, `email`, `billing_address`, and creator/timestamps. It is protected by company membership RLS. Do not create a second customer master.

CRM tables are:
- `crm_customer_assignments` — one current owner per company/customer.
- `crm_assignment_events` — append-only reassignment history.
- `crm_activities` — customer interactions and follow-up data.
- `crm_opportunities` — sales pipeline.
- `crm_after_sales_tasks` — after-sales task tracking.

The V6.7 UI bridge currently still calls legacy, nonexistent `bokan_customers`, `bokan_customer_activities`, `bokan_customer_assignments`, `bokan_salespeople`, and `bokan_sales_opportunities`. The central Sales CRM UI separately calls `customers.customer_name`, `customer_logs`, and `profiles`; those legacy contracts are not the live schema. Therefore, neither the CRM bridge nor the Sales CRM screen is approved for production use yet.

## Additive compatibility migration applied

Live migration: `20261031100616_extend_crm_for_v67_sales_workflow`.

Added to `public.customers`:
- `location text`
- `phones jsonb not null default []`, constrained to a JSON array
- `current_status text not null default 'New Lead'`
- `lead_source text`

Added to `public.crm_activities`:
- `status text`
- `deal_value numeric(18,2)`, nonnegative when supplied
- `units_sold numeric(18,3)`, nonnegative when supplied
- `product_type text`

Added company/name and company/status/date indexes. Existing rows were not populated with invented data. Existing RLS policies remain in force; the new fields inherit the existing table-level access boundaries.

## Required bridge mapping before switching the screens

| V6.7 field | Live target | Mapping rule |
|---|---|---|
| customer_name | customers.name | Translate at the UI boundary; keep UUID as identity |
| contact_person | customers.contact_person | Direct |
| location | customers.location | Direct |
| phone / phones | customers.phone / customers.phones | Store first phone plus full JSON array |
| email | customers.email | Direct |
| current_status | customers.current_status | Direct |
| lead_source | customers.lead_source | Direct |
| assigned representative | crm_customer_assignments.owner_user_id | Read via join; only manager RPC may change it |
| sales_rep | crm_activities.actor_user_id | Must be authenticated user UUID, never a display name |
| activity_type / notes / feedback | crm_activities matching columns | Direct |
| status / deal_value / units_sold / product_type | crm_activities added columns | Direct |
| next action fields | crm_activities.next_action_type / next_action_date | Direct |
| escalation fields | crm_activities.escalated / escalate_reason / escalate_note | Direct |
| reassignment | bokan_reassign_customer_owner RPC | One atomic manager-only operation with mandatory reason |

## Known UI changes still required

1. Replace every CRM reference to the legacy `bokan_*`, `customer_logs`, and `profiles` contracts with the canonical tables and authenticated company context.
2. Render the canonical UUID identity and resolve representative labels from active `company_memberships` plus the approved profile source; do not treat names or email metadata as authorization.
3. Route reassignment through the manager-only RPC and show the append-only event history. Remove direct customer assignment updates.
4. Replace interaction deletion with a reviewed correction/void workflow. The current CRM activity model intentionally grants no ordinary UPDATE/DELETE.
5. Map opportunity and after-sales screens separately; their lifecycle fields are not interchangeable with a customer interaction.
6. Add browser tests for save, reload, second session, active-company switch, cross-company denial, manager reassignment, sales-user denial, and anonymous denial.

## Safety and migration notes

- No customer or activity records were imported or changed.
- No demo records were inserted into live Supabase.
- CRM remains disabled in the production allowlist. The review build remains sample-data-only.
- The first attempt applied the migration under Supabase-generated version `20261031100616`; the repository contains the matching timestamped SQL source. A preliminary draft file with version `20261031090000` also remains in the branch and should be reconciled in a later source-control cleanup; do not apply it as a second migration.
- The four historical missing SQL bodies remain intentionally unreconstructed.
