-- BOKAN ERP V7 initial schema
-- Schema only. Deliberately contains NO tenant rows, users, fixtures or business records.
-- Apply only to a separately provisioned V7 Supabase project after owner approval.
begin;

create extension if not exists pgcrypto;

create type public.company_role as enum ('owner', 'manager', 'sales', 'purchasing', 'operations', 'viewer');
create type public.crm_lead_stage as enum ('new', 'qualified', 'proposal', 'negotiation', 'won', 'lost');
create type public.commercial_document_status as enum ('draft', 'submitted', 'approved', 'rejected', 'sent', 'accepted', 'expired', 'cancelled');
create type public.direct_cost_category as enum ('transportation', 'loading', 'miscellaneous');
create type public.vat_treatment as enum ('exclusive', 'inclusive', 'none');
create type public.task_status as enum ('open', 'in_progress', 'completed', 'cancelled');

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null check (length(trim(legal_name)) between 2 and 180),
  display_name text not null check (length(trim(display_name)) between 2 and 120),
  currency_code text not null default 'ETB' check (currency_code = 'ETB'),
  vat_rate_bps integer not null default 1500 check (vat_rate_bps between 0 and 100000),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.company_memberships (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.company_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company_id, user_id)
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  customer_code text,
  legal_name text not null,
  contact_name text,
  email text,
  phone text,
  address text,
  tax_number text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, customer_code)
);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  supplier_code text,
  legal_name text not null,
  contact_name text,
  email text,
  phone text,
  address text,
  tax_number text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, supplier_code)
);

create table public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  customer_id uuid references public.customers(id),
  title text not null,
  contact_name text,
  phone text,
  email text,
  source text,
  stage public.crm_lead_stage not null default 'new',
  estimated_value numeric(18,2) check (estimated_value is null or estimated_value >= 0),
  assigned_to uuid references auth.users(id),
  next_follow_up_at timestamptz,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.crm_activities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  customer_id uuid references public.customers(id),
  lead_id uuid references public.crm_leads(id),
  activity_type text not null check (activity_type in ('call','visit','meeting','email','note','reminder')),
  subject text not null,
  details text,
  occurred_at timestamptz not null default now(),
  assigned_to uuid references auth.users(id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (customer_id is not null or lead_id is not null)
);

create table public.sales_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  document_number text not null,
  customer_id uuid not null references public.customers(id),
  status public.commercial_document_status not null default 'draft',
  issue_date date not null default current_date,
  valid_until date,
  currency_code text not null default 'ETB' check (currency_code = 'ETB'),
  subtotal numeric(18,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(18,2) not null default 0 check (discount_total >= 0),
  vat_treatment public.vat_treatment not null default 'exclusive',
  vat_rate_bps integer not null default 1500 check (vat_rate_bps between 0 and 100000),
  vat_total numeric(18,2) not null default 0 check (vat_total >= 0),
  grand_total numeric(18,2) not null default 0 check (grand_total >= 0),
  terms text,
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, document_number)
);

create table public.sales_document_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  sales_document_id uuid not null references public.sales_documents(id) on delete cascade,
  description text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_of_measure text not null,
  unit_price numeric(18,2) not null check (unit_price >= 0),
  discount_amount numeric(18,2) not null default 0 check (discount_amount >= 0),
  line_net numeric(18,2) not null check (line_net >= 0),
  created_at timestamptz not null default now()
);

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  order_number text not null,
  supplier_id uuid not null references public.suppliers(id),
  status public.commercial_document_status not null default 'draft',
  order_date date not null default current_date,
  expected_date date,
  currency_code text not null default 'ETB' check (currency_code = 'ETB'),
  subtotal numeric(18,2) not null default 0 check (subtotal >= 0),
  vat_treatment public.vat_treatment not null default 'exclusive',
  vat_rate_bps integer not null default 1500 check (vat_rate_bps between 0 and 100000),
  vat_total numeric(18,2) not null default 0 check (vat_total >= 0),
  grand_total numeric(18,2) not null default 0 check (grand_total >= 0),
  notes text,
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, order_number)
);

create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  description text not null,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_of_measure text not null,
  unit_price numeric(18,2) not null check (unit_price >= 0),
  line_net numeric(18,2) not null check (line_net >= 0),
  created_at timestamptz not null default now()
);

create table public.direct_costs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  sales_document_id uuid references public.sales_documents(id),
  purchase_order_id uuid references public.purchase_orders(id),
  category public.direct_cost_category not null,
  description text not null,
  amount numeric(18,2) not null check (amount >= 0),
  vat_treatment public.vat_treatment not null default 'none',
  vat_rate_bps integer not null default 1500 check (vat_rate_bps between 0 and 100000),
  recoverable_vat boolean not null default false,
  incurred_on date not null default current_date,
  supplier_name text,
  reference_number text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (sales_document_id is not null or purchase_order_id is not null)
);

create table public.delivery_jobs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  sales_document_id uuid references public.sales_documents(id),
  customer_id uuid not null references public.customers(id),
  delivery_reference text not null,
  planned_for timestamptz,
  dispatched_at timestamptz,
  delivered_at timestamptz,
  status text not null default 'planned' check (status in ('planned','scheduled','dispatched','delivered','delayed','cancelled')),
  carrier_name text,
  vehicle_reference text,
  delivery_address text,
  proof_document_id uuid,
  exception_notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (company_id, delivery_reference)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  title text not null,
  details text,
  status public.task_status not null default 'open',
  due_at timestamptz,
  assigned_to uuid references auth.users(id),
  customer_id uuid references public.customers(id),
  lead_id uuid references public.crm_leads(id),
  created_by uuid references auth.users(id),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  storage_bucket text not null,
  storage_path text not null,
  file_name text not null,
  content_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  related_customer_id uuid references public.customers(id),
  related_sales_document_id uuid references public.sales_documents(id),
  related_purchase_order_id uuid references public.purchase_orders(id),
  uploaded_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

alter table public.delivery_jobs
  add constraint delivery_jobs_proof_document_fk
  foreign key (proof_document_id) references public.documents(id);

create table public.audit_events (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id),
  actor_user_id uuid references auth.users(id),
  action text not null,
  entity_table text not null,
  entity_id text,
  occurred_at timestamptz not null default now(),
  request_id text,
  metadata jsonb not null default '{}'::jsonb
);

create schema if not exists private;

create or replace function private.is_company_member(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.company_memberships m
    where m.company_id = target_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
  );
$$;

create or replace function private.has_company_role(target_company_id uuid, allowed_roles public.company_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.company_memberships m
    where m.company_id = target_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any(allowed_roles)
  );
$$;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
revoke all on function private.is_company_member(uuid) from public, anon;
revoke all on function private.has_company_role(uuid, public.company_role[]) from public, anon;
grant execute on function private.is_company_member(uuid) to authenticated;
grant execute on function private.has_company_role(uuid, public.company_role[]) to authenticated;

-- Every business table is tenant-isolated. No broad authenticated read/write grants.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'companies','company_memberships','customers','suppliers','crm_leads','crm_activities',
    'sales_documents','sales_document_lines','purchase_orders','purchase_order_lines',
    'direct_costs','delivery_jobs','tasks','documents','audit_events'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
  end loop;
end $$;

create policy companies_member_read on public.companies
  for select to authenticated using (private.is_company_member(id));
create policy memberships_self_or_manager_read on public.company_memberships
  for select to authenticated using (
    user_id = (select auth.uid())
    or private.has_company_role(company_id, array['owner','manager']::public.company_role[])
  );

-- CRUD access for business workspaces is membership-gated. Role-specific write
-- restrictions are tightened in follow-on policies before the production release.
create policy customers_member_access on public.customers
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy suppliers_member_access on public.suppliers
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy leads_member_access on public.crm_leads
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy crm_activities_member_access on public.crm_activities
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy sales_documents_member_access on public.sales_documents
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy sales_document_lines_member_access on public.sales_document_lines
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy purchase_orders_member_access on public.purchase_orders
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy purchase_order_lines_member_access on public.purchase_order_lines
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy direct_costs_member_access on public.direct_costs
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy delivery_jobs_member_access on public.delivery_jobs
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy tasks_member_access on public.tasks
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy documents_member_access on public.documents
  for all to authenticated
  using (private.is_company_member(company_id))
  with check (private.is_company_member(company_id));
create policy audit_events_member_read on public.audit_events
  for select to authenticated using (private.is_company_member(company_id));

-- Audit events are append-only for authenticated application users.
create policy audit_events_member_insert on public.audit_events
  for insert to authenticated
  with check (
    private.is_company_member(company_id)
    and actor_user_id = (select auth.uid())
  );

grant select on public.companies, public.company_memberships to authenticated;
grant select, insert, update, delete on
  public.customers, public.suppliers, public.crm_leads, public.crm_activities,
  public.sales_documents, public.sales_document_lines, public.purchase_orders,
  public.purchase_order_lines, public.direct_costs, public.delivery_jobs,
  public.tasks, public.documents to authenticated;
grant select, insert on public.audit_events to authenticated;

commit;
