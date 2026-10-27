-- Candidate only: additive Proforma persistence aligned with the existing UUID companies/company_memberships model.
-- This file is intentionally under supabase/candidates, not supabase/migrations.
-- Apply only to a disposable database until the test suite and release review pass.

begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create unique index if not exists companies_id_code_uq on public.companies(id, code);

create table if not exists public.company_proforma_settings (
  company_id uuid primary key references public.companies(id) on delete cascade,
  issuer_tin text,
  issuer_address text,
  issuer_phone text,
  brand_name text,
  title_color text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  company_code text not null,
  bank_name text not null check (length(trim(bank_name)) between 1 and 160),
  account_number text not null check (length(trim(account_number)) between 1 and 120),
  branch_name text,
  account_purpose text,
  display_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint company_bank_accounts_company_code_uq unique (id, company_id),
  constraint company_bank_accounts_company_code_match_fk
    foreign key (company_id, company_code)
    references public.companies(id, code) on update cascade on delete cascade
);

create index if not exists company_bank_accounts_company_active_idx
  on public.company_bank_accounts(company_id, active, display_order);

create table if not exists public.custom_terms (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  company_code text not null,
  category text not null check (category in ('validity','payment','delivery','transport')),
  label text not null check (length(trim(label)) between 1 and 300),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  constraint custom_terms_company_code_match_fk
    foreign key (company_id, company_code)
    references public.companies(id, code) on update cascade on delete cascade,
  constraint custom_terms_company_category_label_uq unique(company_id, category, label)
);

create table if not exists public.proformas (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  company_code text not null,
  proforma_no text not null,
  root_proforma_id uuid references public.proformas(id) on delete restrict,
  version_no integer not null default 1 check (version_no > 0),
  document_action text not null default 'new' check (document_action in ('new','revision','void')),
  customer_name text not null check (length(trim(customer_name)) between 1 and 300),
  customer_tin text not null check (length(trim(customer_tin)) between 1 and 100),
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
  status text not null default 'issued' check (status in ('draft','issued','void')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint proformas_company_code_match_fk
    foreign key (company_id, company_code)
    references public.companies(id, code) on update cascade on delete restrict,
  constraint proformas_company_number_version_uq unique(company_id, proforma_no, version_no),
  constraint proformas_vat_total_consistency_check
    check (abs(grand_total - subtotal_before_vat - vat_amount + discount_amount) <= 0.02),
  constraint proformas_withholding_math_check
    check (abs(withholding_amount - case when withholding_enabled and grand_total > withholding_threshold then round(grand_total * withholding_rate / 100, 2) else 0 end) <= 0.01),
  constraint proformas_net_payable_math_check
    check (abs(net_payable - (grand_total - withholding_amount)) <= 0.01)
);

create index if not exists proformas_company_updated_idx
  on public.proformas(company_id, updated_at desc);
create index if not exists proformas_company_number_idx
  on public.proformas(company_id, proforma_no, version_no desc);

alter table public.company_proforma_settings enable row level security;
alter table public.company_bank_accounts enable row level security;
alter table public.custom_terms enable row level security;
alter table public.proformas enable row level security;

drop policy if exists company_proforma_settings_select_member on public.company_proforma_settings;
create policy company_proforma_settings_select_member on public.company_proforma_settings
  for select to authenticated using (private.has_company_membership(company_id));

drop policy if exists company_bank_accounts_select_member on public.company_bank_accounts;
create policy company_bank_accounts_select_member on public.company_bank_accounts
  for select to authenticated using (active and private.has_company_membership(company_id));

drop policy if exists custom_terms_select_member on public.custom_terms;
create policy custom_terms_select_member on public.custom_terms
  for select to authenticated using (private.has_company_membership(company_id));

drop policy if exists custom_terms_insert_member on public.custom_terms;
create policy custom_terms_insert_member on public.custom_terms
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and private.has_company_membership(company_id)
  );

drop policy if exists proformas_select_member on public.proformas;
create policy proformas_select_member on public.proformas
  for select to authenticated using (private.has_company_membership(company_id));

revoke all on public.company_proforma_settings, public.company_bank_accounts, public.custom_terms, public.proformas from anon, authenticated;
grant select on public.company_proforma_settings, public.company_bank_accounts, public.custom_terms, public.proformas to authenticated;
grant insert on public.custom_terms to authenticated;

create or replace function private.bokan_save_company_proforma_settings(p_company text, p_payload jsonb)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
  v_uid uuid := (select auth.uid());
  v_role text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'Settings payload must be an object'; end if;
  select c.id into v_company_id from public.companies c where c.code = p_company and c.is_active;
  if v_company_id is null then raise exception 'Company is inactive or unavailable'; end if;
  select m.role into v_role from public.company_memberships m
   where m.company_id = v_company_id and m.user_id = v_uid and m.is_active;
  if v_role is null or v_role not in ('owner','admin','manager','accountant') then raise exception 'Company administrator permission required'; end if;
  if (p_payload ? 'tin' and p_payload->'tin' <> 'null'::jsonb and jsonb_typeof(p_payload->'tin') is distinct from 'string')
     or (p_payload ? 'address' and p_payload->'address' <> 'null'::jsonb and jsonb_typeof(p_payload->'address') is distinct from 'string')
     or (p_payload ? 'phone' and p_payload->'phone' <> 'null'::jsonb and jsonb_typeof(p_payload->'phone') is distinct from 'string') then
    raise exception 'Issuer TIN, address and phone must be text';
  end if;
  insert into public.company_proforma_settings(company_id, issuer_tin, issuer_address, issuer_phone, updated_by, updated_at)
  values(
    v_company_id,
    case when p_payload ? 'tin' then nullif(btrim(p_payload->>'tin'), '') else null end,
    case when p_payload ? 'address' then nullif(btrim(p_payload->>'address'), '') else null end,
    case when p_payload ? 'phone' then nullif(btrim(p_payload->>'phone'), '') else null end,
    v_uid, now()
  )
  on conflict(company_id) do update set
    issuer_tin = case when p_payload ? 'tin' then excluded.issuer_tin else public.company_proforma_settings.issuer_tin end,
    issuer_address = case when p_payload ? 'address' then excluded.issuer_address else public.company_proforma_settings.issuer_address end,
    issuer_phone = case when p_payload ? 'phone' then excluded.issuer_phone else public.company_proforma_settings.issuer_phone end,
    updated_by = excluded.updated_by, updated_at = now();
  return true;
end;
$$;

create or replace function public.bokan_save_company_proforma_settings(p_company text, p_payload jsonb)
returns boolean
language sql
security invoker
set search_path = ''
as $$ select private.bokan_save_company_proforma_settings(p_company, p_payload); $$;

revoke all on function private.bokan_save_company_proforma_settings(text,jsonb) from public, anon;
grant execute on function private.bokan_save_company_proforma_settings(text,jsonb) to authenticated;
revoke all on function public.bokan_save_company_proforma_settings(text,jsonb) from public, anon;
grant execute on function public.bokan_save_company_proforma_settings(text,jsonb) to authenticated;

create or replace function private.bokan_save_proforma(
  p_company text,
  p_existing_id uuid,
  p_payload jsonb
)
returns public.proformas
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_company_id uuid;
  v_company_code text;
  v_role text;
  v_existing public.proformas%rowtype;
  v_row public.proformas%rowtype;
  v_customer text;
  v_prefix text;
  v_number text;
  v_next integer;
  v_version integer := 1;
  v_root_id uuid;
  v_action text := 'new';
  v_items jsonb;
  v_terms jsonb;
  v_banks jsonb;
  v_vat_rate numeric(6,3);
  v_discount_percent numeric(6,3);
  v_gross numeric(16,2);
  v_discount_amount numeric(16,2);
  v_discounted_gross numeric(16,2);
  v_subtotal numeric(16,2);
  v_vat_amount numeric(16,2);
  v_grand_total numeric(16,2);
  v_withholding_amount numeric(16,2);
  v_net_payable numeric(16,2);
  v_proforma_date date;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'Invalid Proforma payload'; end if;
  if p_company is null or p_company not in ('PRIME','BLACKROCK') then raise exception 'Invalid company'; end if;

  select c.id, c.code into v_company_id, v_company_code
    from public.companies c where c.code = p_company and c.is_active;
  if v_company_id is null then raise exception 'Company is inactive or unavailable'; end if;

  select m.role into v_role from public.company_memberships m
   where m.company_id = v_company_id and m.user_id = v_uid and m.is_active;
  if v_role is null or v_role not in ('owner','admin','manager','sales','accountant','staff') then
    raise exception 'Active authorized company membership required';
  end if;

  if (p_payload ? 'customer' and jsonb_typeof(p_payload->'customer') is distinct from 'string')
     or (p_payload ? 'tin' and jsonb_typeof(p_payload->'tin') is distinct from 'string')
     or (p_payload ? 'address' and p_payload->'address' <> 'null'::jsonb and jsonb_typeof(p_payload->'address') is distinct from 'string')
     or (p_payload ? 'phone' and p_payload->'phone' <> 'null'::jsonb and jsonb_typeof(p_payload->'phone') is distinct from 'string')
     or (p_payload ? 'contactPerson' and p_payload->'contactPerson' <> 'null'::jsonb and jsonb_typeof(p_payload->'contactPerson') is distinct from 'string')
     or (p_payload ? 'delivery' and p_payload->'delivery' <> 'null'::jsonb and jsonb_typeof(p_payload->'delivery') is distinct from 'string')
     or (p_payload ? 'notes' and p_payload->'notes' <> 'null'::jsonb and jsonb_typeof(p_payload->'notes') is distinct from 'string') then
    raise exception 'Invalid Proforma text fields';
  end if;

  v_customer := btrim(coalesce(p_payload->>'customer',''));
  if v_customer = '' or btrim(coalesce(p_payload->>'tin','')) = '' then raise exception 'Customer name and TIN are required'; end if;
  if (p_payload ? 'vatPct' and jsonb_typeof(p_payload->'vatPct') is distinct from 'number')
     or (p_payload ? 'discountPct' and jsonb_typeof(p_payload->'discountPct') is distinct from 'number')
     or (p_payload ? 'date' and p_payload->'date' <> 'null'::jsonb and jsonb_typeof(p_payload->'date') is distinct from 'string') then
    raise exception 'Invalid Proforma numeric/date fields';
  end if;

  v_vat_rate := coalesce(nullif(p_payload->>'vatPct','')::numeric,15);
  v_discount_percent := coalesce(nullif(p_payload->>'discountPct','')::numeric,0);
  if v_vat_rate < 0 or v_vat_rate > 100 or v_discount_percent < 0 or v_discount_percent > 100 then
    raise exception 'VAT and discount rates must be between 0 and 100';
  end if;
  v_proforma_date := coalesce(nullif(p_payload->>'date','')::date,current_date);
  v_items := p_payload->'items';
  v_terms := coalesce(p_payload->'terms','[]'::jsonb);
  if jsonb_typeof(v_items) is distinct from 'array' or jsonb_array_length(v_items) = 0 then raise exception 'At least one line item is required'; end if;
  if jsonb_typeof(v_terms) is distinct from 'array' then raise exception 'Terms must be an array'; end if;
  if exists (select 1 from jsonb_array_elements(v_terms) t(value) where jsonb_typeof(t.value) is distinct from 'string') then raise exception 'Terms must be text values'; end if;
  if exists (
    select 1 from jsonb_array_elements(v_items) i(value)
    where jsonb_typeof(i.value) is distinct from 'object'
       or jsonb_typeof(i.value->'description') is distinct from 'string'
       or jsonb_typeof(i.value->'qty') is distinct from 'number'
       or jsonb_typeof(i.value->'unit_price') is distinct from 'number'
  ) then raise exception 'Each line item requires description, numeric qty and numeric unit_price'; end if;
  if exists (
    select 1 from jsonb_array_elements(v_items) i(value)
    where btrim(coalesce(i.value->>'description','')) = ''
       or (i.value->>'qty')::numeric <= 0
       or (i.value->>'unit_price')::numeric < 0
  ) then raise exception 'Line quantity must be positive and unit price non-negative'; end if;

  select round(coalesce(sum((i.value->>'qty')::numeric * (i.value->>'unit_price')::numeric),0),2)
    into v_gross from jsonb_array_elements(v_items) i(value);
  v_discount_amount := round(v_gross * v_discount_percent / 100,2);
  v_discounted_gross := round(v_gross - v_discount_amount,2);
  v_subtotal := round(v_gross / (1 + v_vat_rate / 100),2);
  v_vat_amount := round(v_gross - v_subtotal,2);
  v_grand_total := v_discounted_gross;
  v_withholding_amount := case when v_grand_total > 10000 then round(v_grand_total * 3 / 100,2) else 0 end;
  v_net_payable := round(v_grand_total - v_withholding_amount,2);

  select coalesce(jsonb_agg(jsonb_build_object(
    'bank_name', b.bank_name,
    'account_number', b.account_number,
    'purpose', coalesce(b.account_purpose,''),
    'branch_name', coalesce(b.branch_name,'')
  ) order by b.display_order, b.id), '[]'::jsonb)
  into v_banks from public.company_bank_accounts b
  where b.company_id = v_company_id and b.active;

  if p_existing_id is not null then
    select * into v_existing from public.proformas p
     where p.id = p_existing_id and p.company_id = v_company_id and p.status <> 'void';
    if not found then raise exception 'Existing Proforma is unavailable for revision'; end if;
    if v_existing.created_by <> v_uid and v_role not in ('owner','admin','manager','accountant') then raise exception 'Revision permission denied'; end if;
    v_number := v_existing.proforma_no;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_company_id::text || ':' || v_number));
    select coalesce(max(p.version_no),0) + 1 into v_version
      from public.proformas p where p.company_id = v_company_id and p.proforma_no = v_number;
    v_root_id := coalesce(v_existing.root_proforma_id, v_existing.id);
    v_action := 'revision';
  else
    v_prefix := left(regexp_replace(upper(split_part(v_customer,' ',1)), '[^A-Z]', '', 'g'),5);
    if v_prefix = '' then v_prefix := 'CUST'; end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_company_id::text || ':' || v_prefix));
    select coalesce(max(substring(p.proforma_no from '([0-9]{4})$')::integer),999)
      into v_next from public.proformas p
      where p.company_id = v_company_id and p.proforma_no ~ ('^' || v_prefix || '[0-9]{4}$');
    if v_next >= 9999 then raise exception 'Proforma number sequence exhausted for prefix %', v_prefix; end if;
    v_number := v_prefix || lpad((v_next + 1)::text,4,'0');
    v_root_id := null;
    v_version := 1;
  end if;

  insert into public.proformas (
    company_id, company_code, proforma_no, root_proforma_id, version_no, document_action,
    customer_name, customer_tin, customer_address, customer_phone, contact_person,
    delivery_terms, proforma_date, vat_rate, subtotal_before_vat, discount_percent,
    discount_amount, vat_amount, withholding_enabled, withholding_rate, withholding_threshold,
    withholding_amount, grand_total, net_payable, company_tin_snapshot, bank_accounts_snapshot,
    items, notes, terms, status, created_by, updated_by
  ) values (
    v_company_id, v_company_code, v_number, v_root_id, v_version, v_action,
    v_customer, btrim(p_payload->>'tin'), nullif(btrim(p_payload->>'address'), ''),
    nullif(btrim(p_payload->>'phone'), ''), nullif(btrim(p_payload->>'contactPerson'), ''),
    coalesce(p_payload->>'delivery',''), v_proforma_date, v_vat_rate, v_subtotal,
    v_discount_percent, v_discount_amount, v_vat_amount, true, 3, 10000,
    v_withholding_amount, v_grand_total, v_net_payable,
    (select s.issuer_tin from public.company_proforma_settings s where s.company_id = v_company_id),
    v_banks, v_items, nullif(p_payload->>'notes',''), v_terms, 'issued', v_uid, v_uid
  ) returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.bokan_save_proforma(p_company text, p_existing_id uuid, p_payload jsonb)
returns public.proformas
language sql
security invoker
set search_path = ''
as $$ select private.bokan_save_proforma(p_company, p_existing_id, p_payload); $$;

revoke all on function private.bokan_save_proforma(text,uuid,jsonb) from public, anon;
grant execute on function private.bokan_save_proforma(text,uuid,jsonb) to authenticated;
revoke all on function public.bokan_save_proforma(text,uuid,jsonb) from public, anon;
grant execute on function public.bokan_save_proforma(text,uuid,jsonb) to authenticated;

-- Seed empty settings rows only. Business-specific TIN/address/bank details must be verified by the company.
insert into public.company_proforma_settings(company_id)
select c.id from public.companies c where c.code in ('PRIME','BLACKROCK')
on conflict(company_id) do nothing;

commit;
