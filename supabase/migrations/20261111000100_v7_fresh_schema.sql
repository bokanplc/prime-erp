-- BOKAN ERP V7 schema foundation.
-- DDL only: deliberately contains NO company, user, customer, supplier,
-- product, stock, purchase, sales, price, balance, or transaction seed rows.
-- Apply only to an isolated V7 Supabase project after owner approval.

begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null check (length(trim(legal_name)) between 2 and 200),
  display_name text not null check (length(trim(display_name)) between 2 and 120),
  currency_code text not null default 'ETB' check (currency_code = 'ETB'),
  vat_rate numeric(5,2) not null default 15.00 check (vat_rate >= 0 and vat_rate <= 100),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_memberships (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  role text not null check (role in ('owner','admin','manager','sales','purchasing','data_entry','viewer')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company_id, user_id)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  customer_code text,
  legal_name text not null,
  display_name text,
  phone text,
  email text,
  tax_id text,
  address text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, customer_code)
);

create table if not exists public.customer_contacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete cascade,
  full_name text not null,
  job_title text,
  phone text,
  email text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  supplier_code text,
  legal_name text not null,
  display_name text,
  phone text,
  email text,
  tax_id text,
  address text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, supplier_code)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  sku text,
  name text not null,
  description text,
  unit_of_measure text not null default 'pcs',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, sku)
);
-- This is a product catalogue only. No quantity, on-hand, stock ledger,
-- receiving, stock posting, inventory valuation or inventory cost columns.

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete set null,
  title text not null,
  contact_name text,
  phone text,
  email text,
  source text,
  stage text not null default 'new' check (stage in ('new','qualified','proposal','negotiation','won','lost')),
  estimated_value numeric(14,2) check (estimated_value is null or estimated_value >= 0),
  assigned_to uuid references auth.users(id) on delete set null,
  next_follow_up_at timestamptz,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_activities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete cascade,
  lead_id uuid references public.leads(id) on delete cascade,
  activity_type text not null check (activity_type in ('call','visit','meeting','email','note','other')),
  subject text not null,
  details text,
  occurred_at timestamptz not null default now(),
  assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (customer_id is not null or lead_id is not null)
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  title text not null,
  description text,
  due_at timestamptz,
  status text not null default 'open' check (status in ('open','in_progress','done','cancelled')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  assigned_to uuid references auth.users(id) on delete set null,
  customer_id uuid references public.customers(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quotations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  quotation_number text not null,
  customer_id uuid not null references public.customers(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','submitted','approved','sent','accepted','rejected','expired','cancelled')),
  issue_date date not null default current_date,
  valid_until date,
  currency_code text not null default 'ETB' check (currency_code = 'ETB'),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(14,2) not null default 0 check (discount_total >= 0),
  vat_rate numeric(5,2) not null default 15 check (vat_rate >= 0 and vat_rate <= 100),
  vat_total numeric(14,2) not null default 0 check (vat_total >= 0),
  grand_total numeric(14,2) not null default 0 check (grand_total >= 0),
  terms text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, quotation_number)
);

create table if not exists public.quotation_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  quotation_id uuid not null references public.quotations(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  description text not null,
  unit_of_measure text not null default 'pcs',
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  vat_rate numeric(5,2) not null default 15 check (vat_rate >= 0 and vat_rate <= 100),
  line_total numeric(14,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  order_number text not null,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','submitted','approved','sent','confirmed','cancelled','closed')),
  order_date date not null default current_date,
  expected_date date,
  currency_code text not null default 'ETB' check (currency_code = 'ETB'),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  vat_total numeric(14,2) not null default 0 check (vat_total >= 0),
  grand_total numeric(14,2) not null default 0 check (grand_total >= 0),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, order_number)
);

create table if not exists public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  description text not null,
  unit_of_measure text not null default 'pcs',
  requested_quantity numeric(14,3) not null check (requested_quantity > 0),
  quoted_unit_price numeric(14,2) not null check (quoted_unit_price >= 0),
  vat_rate numeric(5,2) not null default 15 check (vat_rate >= 0 and vat_rate <= 100),
  line_total numeric(14,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);
-- Purchase orders capture requested/quoted commercial values only. There is
-- deliberately no receiving workflow or inventory movement table.

create table if not exists public.transaction_direct_costs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  quotation_id uuid references public.quotations(id) on delete cascade,
  purchase_order_id uuid references public.purchase_orders(id) on delete cascade,
  category text not null check (category in ('transportation','loading','miscellaneous')),
  description text not null,
  amount numeric(14,2) not null check (amount >= 0),
  vat_treatment text not null check (vat_treatment in ('exclusive','inclusive','none')),
  vat_rate numeric(5,2) not null default 15 check (vat_rate >= 0 and vat_rate <= 100),
  input_vat_recoverable boolean not null default false,
  incurred_on date not null default current_date,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check ((quotation_id is not null)::integer + (purchase_order_id is not null)::integer = 1)
);

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  quotation_id uuid references public.quotations(id) on delete set null,
  delivery_number text not null,
  status text not null default 'planned' check (status in ('planned','scheduled','dispatched','delivered','exception','cancelled')),
  planned_for timestamptz,
  dispatched_at timestamptz,
  delivered_at timestamptz,
  destination text,
  transport_reference text,
  delivery_notes text,
  exception_notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, delivery_number)
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  storage_path text not null,
  file_name text not null,
  content_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  customer_id uuid references public.customers(id) on delete set null,
  quotation_id uuid references public.quotations(id) on delete set null,
  purchase_order_id uuid references public.purchase_orders(id) on delete set null,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (company_id, storage_path)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create or replace function public.is_company_member(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.company_memberships m
    where m.company_id = target_company_id
      and m.user_id = auth.uid()
      and m.is_active = true
  );
$$;

create or replace function public.has_company_role(target_company_id uuid, allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.company_memberships m
    where m.company_id = target_company_id
      and m.user_id = auth.uid()
      and m.is_active = true
      and m.role = any(allowed_roles)
  );
$$;

revoke all on function public.is_company_member(uuid) from public;
revoke all on function public.has_company_role(uuid, text[]) from public;
grant execute on function public.is_company_member(uuid) to authenticated;
grant execute on function public.has_company_role(uuid, text[]) to authenticated;

alter table public.companies enable row level security;
alter table public.company_memberships enable row level security;
alter table public.customers enable row level security;
alter table public.customer_contacts enable row level security;
alter table public.suppliers enable row level security;
alter table public.products enable row level security;
alter table public.leads enable row level security;
alter table public.crm_activities enable row level security;
alter table public.tasks enable row level security;
alter table public.quotations enable row level security;
alter table public.quotation_lines enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
alter table public.transaction_direct_costs enable row level security;
alter table public.deliveries enable row level security;
alter table public.documents enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_events enable row level security;

create policy companies_select_member on public.companies
for select to authenticated using (public.is_company_member(id));

create policy memberships_select_self_or_admin on public.company_memberships
for select to authenticated using (
  user_id = auth.uid() or public.has_company_role(company_id, array['owner','admin'])
);

-- Business tables are tenant-scoped. Role checks limit write access by module.
create policy customers_select on public.customers for select to authenticated
using (public.is_company_member(company_id));
create policy customers_insert on public.customers for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy customers_update on public.customers for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy customers_delete on public.customers for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy contacts_select on public.customer_contacts for select to authenticated
using (public.is_company_member(company_id));
create policy contacts_insert on public.customer_contacts for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy contacts_update on public.customer_contacts for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy contacts_delete on public.customer_contacts for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy suppliers_select on public.suppliers for select to authenticated
using (public.is_company_member(company_id));
create policy suppliers_insert on public.suppliers for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']));
create policy suppliers_update on public.suppliers for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']));
create policy suppliers_delete on public.suppliers for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy products_select on public.products for select to authenticated
using (public.is_company_member(company_id));
create policy products_insert on public.products for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy products_update on public.products for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy products_delete on public.products for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy leads_select on public.leads for select to authenticated using (public.is_company_member(company_id));
create policy leads_insert on public.leads for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy leads_update on public.leads for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy leads_delete on public.leads for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy activities_select on public.crm_activities for select to authenticated using (public.is_company_member(company_id));
create policy activities_insert on public.crm_activities for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy activities_update on public.crm_activities for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy activities_delete on public.crm_activities for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy tasks_select on public.tasks for select to authenticated using (public.is_company_member(company_id));
create policy tasks_insert on public.tasks for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy tasks_update on public.tasks for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy tasks_delete on public.tasks for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy quotations_select on public.quotations for select to authenticated using (public.is_company_member(company_id));
create policy quotations_insert on public.quotations for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy quotations_update on public.quotations for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy quotations_delete on public.quotations for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy quotation_lines_select on public.quotation_lines for select to authenticated using (public.is_company_member(company_id));
create policy quotation_lines_insert on public.quotation_lines for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy quotation_lines_update on public.quotation_lines for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','data_entry']));
create policy quotation_lines_delete on public.quotation_lines for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy purchase_orders_select on public.purchase_orders for select to authenticated using (public.is_company_member(company_id));
create policy purchase_orders_insert on public.purchase_orders for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']));
create policy purchase_orders_update on public.purchase_orders for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']));
create policy purchase_orders_delete on public.purchase_orders for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy purchase_lines_select on public.purchase_order_lines for select to authenticated using (public.is_company_member(company_id));
create policy purchase_lines_insert on public.purchase_order_lines for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']));
create policy purchase_lines_update on public.purchase_order_lines for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']));
create policy purchase_lines_delete on public.purchase_order_lines for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy direct_costs_select on public.transaction_direct_costs for select to authenticated using (public.is_company_member(company_id));
create policy direct_costs_insert on public.transaction_direct_costs for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy direct_costs_update on public.transaction_direct_costs for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy direct_costs_delete on public.transaction_direct_costs for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy deliveries_select on public.deliveries for select to authenticated using (public.is_company_member(company_id));
create policy deliveries_insert on public.deliveries for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy deliveries_update on public.deliveries for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']))
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy deliveries_delete on public.deliveries for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy documents_select on public.documents for select to authenticated using (public.is_company_member(company_id));
create policy documents_insert on public.documents for insert to authenticated
with check (public.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']));
create policy documents_delete on public.documents for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));

create policy notifications_select_own on public.notifications for select to authenticated
using (recipient_user_id = auth.uid() and public.is_company_member(company_id));
create policy notifications_update_own on public.notifications for update to authenticated
using (recipient_user_id = auth.uid() and public.is_company_member(company_id))
with check (recipient_user_id = auth.uid() and public.is_company_member(company_id));

create policy audit_events_select_admin on public.audit_events for select to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']));
create policy audit_events_insert_actor on public.audit_events for insert to authenticated
with check (actor_user_id = auth.uid() and public.is_company_member(company_id));
-- Intentionally no UPDATE or DELETE policy for audit_events.

create index if not exists memberships_user_company_idx on public.company_memberships(user_id, company_id) where is_active;
create index if not exists customers_company_name_idx on public.customers(company_id, legal_name);
create index if not exists suppliers_company_name_idx on public.suppliers(company_id, legal_name);
create index if not exists leads_company_stage_idx on public.leads(company_id, stage, created_at desc);
create index if not exists activities_company_time_idx on public.crm_activities(company_id, occurred_at desc);
create index if not exists tasks_company_due_idx on public.tasks(company_id, due_at) where status in ('open','in_progress');
create index if not exists quotations_company_date_idx on public.quotations(company_id, issue_date desc);
create index if not exists purchase_orders_company_date_idx on public.purchase_orders(company_id, order_date desc);
create index if not exists direct_costs_company_date_idx on public.transaction_direct_costs(company_id, incurred_on desc);
create index if not exists deliveries_company_status_idx on public.deliveries(company_id, status, planned_for);
create index if not exists audit_events_company_time_idx on public.audit_events(company_id, occurred_at desc);

commit;
