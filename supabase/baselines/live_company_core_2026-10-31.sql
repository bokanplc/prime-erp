-- LIVE SCHEMA BASELINE SNAPSHOT — 2026-10-31
-- Project: kafiwnuynjemufnankvi (BOKAN ERP)
-- Scope: companies, company_memberships, customers, sales_documents and their
-- directly required RLS helper functions, indexes, policies and grants.
--
-- IMPORTANT:
-- This is a catalog-derived snapshot of the CURRENT live schema. It is NOT
-- represented as the exact historical SQL body of the missing migrations
-- 20261025065910, 20261025072547, 20261025124247 or 20261025124312.
-- It is a source-controlled reconstruction reference for future clean-room
-- bootstrap/reconciliation. Do not apply it to the existing live project.
-- The executable forward migration history remains in supabase/migrations.

create schema if not exists private;

create or replace function private.can_manage_company(p_company_id uuid)
returns boolean
language sql stable security definer
set search_path to ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.company_memberships m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role in ('owner','admin','manager')
  );
$$;

create or replace function private.has_company_membership(p_company_id uuid)
returns boolean
language sql stable security definer
set search_path to ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.company_memberships m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
  );
$$;

create table public.companies (
  id uuid not null default gen_random_uuid(),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint companies_pkey primary key (id),
  constraint companies_code_key unique (code),
  constraint companies_code_check check (
    code = upper(code) and length(code) >= 2 and length(code) <= 32
  )
);
create unique index companies_id_code_uq on public.companies using btree (id,code);

create table public.company_memberships (
  id uuid not null default gen_random_uuid(),
  company_id uuid not null,
  user_id uuid not null,
  role text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint company_memberships_pkey primary key (id),
  constraint company_memberships_company_id_id_key unique (company_id,id),
  constraint company_memberships_company_id_user_id_key unique (company_id,user_id),
  constraint company_memberships_company_id_fkey foreign key (company_id)
    references public.companies(id) on delete cascade,
  constraint company_memberships_user_id_fkey foreign key (user_id)
    references auth.users(id) on delete cascade,
  constraint company_memberships_role_check check (
    role = any (array['owner','admin','manager','hr','sales','accountant','inventory','staff','viewer']::text[])
  )
);
create index company_memberships_user_active_idx
  on public.company_memberships using btree (user_id,is_active,company_id);

create table public.customers (
  id uuid not null default gen_random_uuid(),
  company_id uuid not null,
  code text,
  name text not null,
  contact_person text,
  email text,
  phone text,
  tax_number text,
  billing_address text,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  location text,
  phones jsonb not null default '[]'::jsonb,
  current_status text not null default 'New Lead',
  lead_source text,
  customer_name text generated always as (name) stored,
  assigned_rep uuid,
  constraint customers_pkey primary key (id),
  constraint customers_company_id_code_key unique (company_id,code),
  constraint customers_company_id_id_key unique (company_id,id),
  constraint customers_company_id_fkey foreign key (company_id)
    references public.companies(id) on delete cascade,
  constraint customers_created_by_fkey foreign key (created_by)
    references auth.users(id) on delete set null,
  constraint customers_assigned_rep_fkey foreign key (assigned_rep)
    references auth.users(id) on delete set null,
  constraint customers_phones_array_check check (jsonb_typeof(phones) = 'array')
);
create index customers_company_assigned_rep_idx on public.customers using btree (company_id,assigned_rep);
create index customers_company_name_idx on public.customers using btree (company_id,name);
create index customers_created_by_idx on public.customers using btree (created_by);

create table public.sales_documents (
  id uuid not null default gen_random_uuid(),
  company_id uuid not null,
  customer_id uuid,
  document_type text not null,
  document_number text not null,
  status text not null default 'draft',
  document_date date not null default current_date,
  due_date date,
  currency_code text not null default 'ETB',
  subtotal numeric(14,2) not null default 0,
  tax_total numeric(14,2) not null default 0,
  discount_total numeric(14,2) not null default 0,
  grand_total numeric(14,2) not null default 0,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sales_documents_pkey primary key (id),
  constraint sales_documents_company_id_id_key unique (company_id,id),
  constraint sales_documents_company_id_document_type_document_number_key
    unique (company_id,document_type,document_number),
  constraint sales_documents_company_id_fkey foreign key (company_id)
    references public.companies(id) on delete cascade,
  constraint sales_documents_created_by_fkey foreign key (created_by)
    references auth.users(id) on delete set null,
  constraint sales_documents_customer_same_company_fk foreign key (company_id,customer_id)
    references public.customers(company_id,id) on delete restrict,
  constraint sales_documents_currency_code_check check (length(currency_code) = 3),
  constraint sales_documents_discount_total_check check (discount_total >= 0),
  constraint sales_documents_document_type_check check (
    document_type = any (array['quotation','proforma','sales_order','invoice','credit_note']::text[])
  ),
  constraint sales_documents_grand_total_check check (grand_total >= 0),
  constraint sales_documents_status_check check (
    status = any (array['draft','submitted','approved','posted','partially_paid','paid','cancelled','void']::text[])
  ),
  constraint sales_documents_subtotal_check check (subtotal >= 0),
  constraint sales_documents_tax_total_check check (tax_total >= 0)
);
create index sales_documents_company_customer_idx on public.sales_documents using btree (company_id,customer_id);
create index sales_documents_company_date_idx on public.sales_documents using btree (company_id,document_date desc);
create index sales_documents_company_status_idx on public.sales_documents using btree (company_id,status);
create index sales_documents_created_by_idx on public.sales_documents using btree (created_by);

alter table public.companies enable row level security;
alter table public.company_memberships enable row level security;
alter table public.customers enable row level security;
alter table public.sales_documents enable row level security;

create policy companies_select_member on public.companies
  for select to authenticated using (private.has_company_membership(id));
create policy memberships_select_self_or_manager on public.company_memberships
  for select to authenticated using (
    user_id = (select auth.uid()) or private.can_manage_company(company_id)
  );

create policy customers_select_member on public.customers
  for select to authenticated using (private.has_company_membership(company_id));
create policy customers_insert_sales on public.customers
  for insert to authenticated with check (
    private.can_manage_company(company_id) or exists (
      select 1 from public.company_memberships m
      where m.company_id=customers.company_id
        and m.user_id=(select auth.uid())
        and m.is_active
        and m.role=any(array['sales','staff']::text[])
    )
  );
create policy customers_update_sales on public.customers
  for update to authenticated using (
    private.can_manage_company(company_id) or exists (
      select 1 from public.company_memberships m
      where m.company_id=customers.company_id
        and m.user_id=(select auth.uid())
        and m.is_active
        and m.role=any(array['sales','staff']::text[])
    )
  ) with check (
    private.can_manage_company(company_id) or exists (
      select 1 from public.company_memberships m
      where m.company_id=customers.company_id
        and m.user_id=(select auth.uid())
        and m.is_active
        and m.role=any(array['sales','staff']::text[])
    )
  );
create policy customers_delete_manager on public.customers
  for delete to authenticated using (private.can_manage_company(company_id));

create policy sales_documents_select_member on public.sales_documents
  for select to authenticated using (private.has_company_membership(company_id));
create policy sales_documents_insert_sales on public.sales_documents
  for insert to authenticated with check (
    private.can_manage_company(company_id) or exists (
      select 1 from public.company_memberships m
      where m.company_id=sales_documents.company_id
        and m.user_id=(select auth.uid())
        and m.is_active
        and m.role=any(array['sales','accountant','staff']::text[])
    )
  );
create policy sales_documents_update_sales on public.sales_documents
  for update to authenticated using (
    private.can_manage_company(company_id) or exists (
      select 1 from public.company_memberships m
      where m.company_id=sales_documents.company_id
        and m.user_id=(select auth.uid())
        and m.is_active
        and m.role=any(array['sales','accountant','staff']::text[])
    )
  ) with check (
    private.can_manage_company(company_id) or exists (
      select 1 from public.company_memberships m
      where m.company_id=sales_documents.company_id
        and m.user_id=(select auth.uid())
        and m.is_active
        and m.role=any(array['sales','accountant','staff']::text[])
    )
  );
create policy sales_documents_delete_manager on public.sales_documents
  for delete to authenticated using (private.can_manage_company(company_id));

revoke all on public.companies,public.company_memberships,public.customers,public.sales_documents from anon;
grant all privileges on public.companies,public.company_memberships,public.sales_documents to authenticated;
grant select,insert,update on public.customers to authenticated;
grant all privileges on public.companies,public.company_memberships,public.customers,public.sales_documents to service_role;
