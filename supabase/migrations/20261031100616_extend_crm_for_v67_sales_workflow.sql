-- Additive CRM compatibility fields for the existing V6.7 Sales CRM workflow.
-- Existing canonical customers and CRM tables remain the only source of truth.
begin;

alter table public.customers
  add column if not exists location text,
  add column if not exists phones jsonb not null default '[]'::jsonb,
  add column if not exists current_status text not null default 'New Lead',
  add column if not exists lead_source text;

alter table public.customers
  add constraint customers_phones_array_check
  check (jsonb_typeof(phones) = 'array');

alter table public.crm_activities
  add column if not exists status text,
  add column if not exists deal_value numeric(18,2),
  add column if not exists units_sold numeric(18,3),
  add column if not exists product_type text;

alter table public.crm_activities
  add constraint crm_activities_deal_value_nonnegative_check
  check (deal_value is null or deal_value >= 0);

alter table public.crm_activities
  add constraint crm_activities_units_sold_nonnegative_check
  check (units_sold is null or units_sold >= 0);

create index if not exists customers_company_name_idx
  on public.customers(company_id, name);
create index if not exists crm_activities_company_status_date_idx
  on public.crm_activities(company_id, status, activity_at desc);

commit;
