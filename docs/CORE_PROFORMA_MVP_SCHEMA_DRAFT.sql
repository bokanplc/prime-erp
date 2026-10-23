-- BOKAN ERP V6.7 — first-slice schema draft (NOT APPLIED)
-- Scope: Supabase Auth profiles + company issuer master + read-only bank accounts + proforma persistence.
-- Deliberately does not create the remaining HR/finance/CRM/logistics tables.
-- Review and test on a disposable project before any production application.

begin;

create table if not exists public.companies (
  code text primary key check (code in ('PRIME','BLACKROCK')),
  legal_name text not null,
  brand_name text,
  tin text not null,
  address text,
  phone text,
  proforma_title_color text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null check (role in ('admin','management','sales_manager','sales','accounting','hr','data_entry')),
  department text,
  company_code text not null check (company_code in ('PRIME','BLACKROCK','GROUP')),
  active boolean not null default true,
  terminated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  company_code text not null references public.companies(code),
  bank_name text not null,
  account_number text not null,
  branch_name text,
  account_purpose text,
  display_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.proformas (
  id uuid primary key default gen_random_uuid(),
  company_code text not null references public.companies(code),
  proforma_no text not null,
  root_proforma_id uuid references public.proformas(id) on delete restrict,
  version_no integer not null default 1 check (version_no > 0),
  document_action text not null default 'new' check (document_action in ('new','update','void','revision')),
  customer_name text not null,
  customer_tin text not null,
  customer_address text,
  customer_phone text,
  contact_person text,
  delivery_terms text not null default '',
  proforma_date date not null default current_date,
  vat_rate numeric(6,3) not null default 15 check (vat_rate >= 0 and vat_rate <= 100),
  subtotal_before_vat numeric(16,2) not null default 0 check (subtotal_before_vat >= 0),
  discount_percent numeric(6,3) not null default 0 check (discount_percent >= 0 and discount_percent <= 100),
  discount_amount numeric(16,2) not null default 0 check (discount_amount >= 0),
  vat_amount numeric(16,2) not null default 0 check (vat_amount >= 0),
  withholding_enabled boolean not null default true,
  withholding_rate numeric(6,3) not null default 3 check (withholding_rate >= 0 and withholding_rate <= 100),
  withholding_threshold numeric(16,2) not null default 10000 check (withholding_threshold >= 0),
  withholding_amount numeric(16,2) not null default 0 check (withholding_amount >= 0),
  grand_total numeric(16,2) not null default 0 check (grand_total >= 0),
  net_payable numeric(16,2) not null default 0 check (net_payable >= 0),
  company_tin_snapshot text,
  bank_accounts_snapshot jsonb not null default '[]'::jsonb check (jsonb_typeof(bank_accounts_snapshot) = 'array'),
  items jsonb not null default '[]'::jsonb check (jsonb_typeof(items) = 'array'),
  notes text,
  terms jsonb not null default '[]'::jsonb check (jsonb_typeof(terms) = 'array'),
  status text not null default 'draft' check (status in ('draft','issued','void')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint proformas_company_number_version_uq unique(company_code,proforma_no,version_no)
);

create index if not exists proformas_company_updated_idx
  on public.proformas(company_code, updated_at desc);
create index if not exists company_bank_accounts_company_active_idx
  on public.company_bank_accounts(company_code, active, display_order);

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.company_bank_accounts enable row level security;
alter table public.proformas enable row level security;

-- The profile is the source of app role/company scope. Users cannot self-edit
-- role, active status, termination, or company assignment through the Data API.
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists companies_select_member on public.companies;
create policy companies_select_member on public.companies
  for select to authenticated
  using (
    active and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.active and p.terminated_at is null
        and (p.company_code = code or (p.company_code = 'GROUP' and p.role in ('admin','management')))
    )
  );

drop policy if exists companies_update_authorized on public.companies;
create policy companies_update_authorized on public.companies
  for update to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.active and p.terminated_at is null
        and p.role in ('admin','accounting')
        and (p.company_code = code or (p.company_code = 'GROUP' and p.role = 'admin'))
    )
  )
  with check (active);

drop policy if exists company_banks_select_member on public.company_bank_accounts;
create policy company_banks_select_member on public.company_bank_accounts
  for select to authenticated
  using (
    active and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.active and p.terminated_at is null
        and (p.company_code = company_bank_accounts.company_code or (p.company_code = 'GROUP' and p.role in ('admin','management')))
    )
  );

drop policy if exists proformas_select_member on public.proformas;
create policy proformas_select_member on public.proformas
  for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.active and p.terminated_at is null
        and p.role in ('admin','management','sales_manager','sales','accounting','data_entry')
        and (p.company_code = proformas.company_code or (p.company_code = 'GROUP' and p.role in ('admin','management')))
    )
  );

drop policy if exists proformas_insert_member on public.proformas;
create policy proformas_insert_member on public.proformas
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and updated_by = (select auth.uid())
    and status = 'draft'
    and version_no > 0
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.active and p.terminated_at is null
        and p.role in ('admin','management','sales_manager','sales','accounting','data_entry')
        and (p.company_code = proformas.company_code or (p.company_code = 'GROUP' and p.role in ('admin','management')))
    )
  );

-- Keep grants narrow. No client-side delete/update of issued proformas or bank
-- accounts; bank maintenance remains disabled until an atomic audited workflow exists.
revoke all on public.companies, public.profiles, public.company_bank_accounts, public.proformas from anon, authenticated;
grant select on public.profiles to authenticated;
grant select on public.companies to authenticated;
grant update (tin,address,phone) on public.companies to authenticated;
grant select on public.company_bank_accounts to authenticated;
grant select, insert on public.proformas to authenticated;

-- Idempotent, company-scoped proforma number allocation. SECURITY INVOKER is
-- intentional: RLS and grants remain in force. It does not create the proforma.
create or replace function public.bokan_next_proforma_number(p_company text, p_customer text)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_prefix text;
  v_next integer;
  v_number text;
begin
  if p_company not in ('PRIME','BLACKROCK') or coalesce(trim(p_customer),'') = '' then
    raise exception 'Invalid company or customer';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.active and p.terminated_at is null
      and p.role in ('admin','management','sales_manager','sales','accounting','data_entry')
      and (p.company_code = p_company or (p.company_code = 'GROUP' and p.role in ('admin','management')))
  ) then
    raise exception 'Not authorized for this company';
  end if;

  v_prefix := left(regexp_replace(upper(split_part(trim(p_customer),' ',1)), '[^A-Z]', '', 'g'),5);
  if v_prefix = '' then v_prefix := 'CUST'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_company || ':' || v_prefix));

  select coalesce(max(nullif(regexp_replace(proforma_no, '^.*?([0-9]{4})$', '\1'), '')::integer),999)
    into v_next
    from public.proformas
   where company_code = p_company
     and proforma_no like v_prefix || '%'
     and proforma_no ~ '[0-9]{4}$';

  v_number := v_prefix || lpad((v_next + 1)::text,4,'0');
  return v_number;
end;
$$;

revoke all on function public.bokan_next_proforma_number(text,text) from public, anon;
grant execute on function public.bokan_next_proforma_number(text,text) to authenticated;

-- Seed legal entities with the confirmed TINs. PRIME phone is intentionally
-- NULL pending owner verification; do not copy BlackRock's number by default.
insert into public.companies(code,legal_name,brand_name,tin,address,phone,proforma_title_color,active)
values
  ('PRIME','PRIME Investment Group PLC','PRIME Investment Group','009588209','Addis Ababa, Ethiopia',null,'#8B0000',true),
  ('BLACKROCK','BlackRock Investment PLC','BlackRock Investment','00930533495','Meskel Flower, Addis Ababa, Ethiopia','978 23 48 20','#E17D00',true)
on conflict(code) do update set
  legal_name=excluded.legal_name,
  brand_name=excluded.brand_name,
  tin=excluded.tin,
  address=excluded.address,
  proforma_title_color=excluded.proforma_title_color,
  active=excluded.active,
  updated_at=now();

commit;
