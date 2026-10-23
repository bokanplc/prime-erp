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
  constraint proformas_company_number_version_uq unique(company_code,proforma_no,version_no),
  constraint proformas_vat_total_consistency_check check (abs(grand_total - subtotal_before_vat - vat_amount) <= 0.02),
  constraint proformas_withholding_math_check check (
    abs(withholding_amount - case when withholding_enabled and grand_total > withholding_threshold then round(grand_total * withholding_rate / 100, 2) else 0 end) <= 0.01
  ),
  constraint proformas_net_payable_math_check check (abs(net_payable - (grand_total - withholding_amount)) <= 0.01)
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

-- Atomic proforma number allocation + version insert.
-- The lock remains held through INSERT, unlike a candidate-number RPC followed by a separate client insert.
-- SECURITY INVOKER is intentional: table grants and RLS remain in force.
create or replace function public.bokan_save_proforma(
  p_company text,
  p_existing_id uuid,
  p_payload jsonb
)
returns public.proformas
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_company public.companies%rowtype;
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
  v_withholding_enabled boolean;
  v_withholding_rate numeric(6,3);
  v_withholding_threshold numeric(16,2);
  v_withholding_amount numeric(16,2);
  v_net_payable numeric(16,2);
  v_proforma_date date;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;
  if p_company not in ('PRIME','BLACKROCK') or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Invalid company or proforma payload';
  end if;

  select * into v_profile
    from public.profiles p
   where p.id = (select auth.uid())
     and p.active and p.terminated_at is null
     and p.role in ('admin','management','sales_manager','sales','accounting','data_entry')
     and (p.company_code = p_company or (p.company_code = 'GROUP' and p.role in ('admin','management')));
  if not found then
    raise exception 'Not authorized for this company';
  end if;

  select * into v_company
    from public.companies c
   where c.code = p_company and c.active;
  if not found then
    raise exception 'Company is inactive or unavailable';
  end if;

  v_customer := trim(coalesce(p_payload->>'customer',''));
  if v_customer = '' or trim(coalesce(p_payload->>'tin','')) = '' then
    raise exception 'Customer name and TIN are required';
  end if;

  v_vat_rate := coalesce(nullif(p_payload->>'vatPct','')::numeric,15);
  v_discount_percent := coalesce(nullif(p_payload->>'discountPct','')::numeric,0);
  v_withholding_enabled := coalesce(nullif(p_payload->>'withholdingEnabled','')::boolean,true);
  v_withholding_rate := coalesce(nullif(p_payload->>'withholdingRate','')::numeric,3);
  v_withholding_threshold := coalesce(nullif(p_payload->>'withholdingThreshold','')::numeric,10000);
  v_proforma_date := coalesce(nullif(p_payload->>'date','')::date,current_date);
  v_items := p_payload->'items';
  v_terms := coalesce(p_payload->'terms','[]'::jsonb);

  if v_vat_rate < 0 or v_vat_rate > 100
     or v_discount_percent < 0 or v_discount_percent > 100
     or v_withholding_rate < 0 or v_withholding_rate > 100
     or v_withholding_threshold < 0 then
    raise exception 'Invalid tax, discount, or withholding settings';
  end if;
  if coalesce(jsonb_typeof(v_items),'') <> 'array' then
    raise exception 'Line items must be an array';
  end if;
  if jsonb_array_length(v_items) = 0 then
    raise exception 'At least one line item is required';
  end if;
  if jsonb_typeof(v_terms) <> 'array' then
    raise exception 'Terms must be an array';
  end if;
  if exists (
    select 1
      from jsonb_array_elements(v_items) as item(value)
     where coalesce(trim(item.value->>'description'),'') = ''
        or coalesce((item.value->>'qty')::numeric,0) <= 0
        or coalesce((item.value->>'unit_price')::numeric,-1) < 0
  ) then
    raise exception 'Every line item requires a description, positive quantity, and non-negative VAT-inclusive unit price';
  end if;

  select round(coalesce(sum((item.value->>'qty')::numeric * (item.value->>'unit_price')::numeric),0),2)
    into v_gross
    from jsonb_array_elements(v_items) as item(value);
  v_discount_amount := round(v_gross * v_discount_percent / 100,2);
  v_discounted_gross := round(v_gross - v_discount_amount,2);
  v_subtotal := round(v_discounted_gross / (1 + v_vat_rate / 100),2);
  v_vat_amount := round(v_discounted_gross - v_subtotal,2);
  v_grand_total := v_discounted_gross;
  v_withholding_amount := case
    when v_withholding_enabled and v_grand_total > v_withholding_threshold
      then round(v_grand_total * v_withholding_rate / 100,2)
    else 0
  end;
  v_net_payable := round(v_grand_total - v_withholding_amount,2);

  -- Issuer identity and bank details are read from the protected company tables,
  -- not trusted from browser-supplied snapshots.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bank_name', b.bank_name,
        'account_number', b.account_number,
        'purpose', coalesce(b.account_purpose,''),
        'branch_name', coalesce(b.branch_name,'')
      ) order by b.display_order, b.id
    ),
    '[]'::jsonb
  ) into v_banks
    from public.company_bank_accounts b
   where b.company_code = p_company and b.active;

  if p_existing_id is not null then
    select * into v_existing
      from public.proformas pf
     where pf.id = p_existing_id
       and pf.company_code = p_company
       and pf.status <> 'void';
    if not found then
      raise exception 'Existing proforma is unavailable for revision';
    end if;
    v_number := v_existing.proforma_no;
    v_prefix := regexp_replace(v_number,'[0-9]{4}$','');
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_company || ':' || v_number));
    select coalesce(max(pf.version_no),0) + 1
      into v_version
      from public.proformas pf
     where pf.company_code = p_company and pf.proforma_no = v_number;
    v_root_id := coalesce(v_existing.root_proforma_id,v_existing.id);
    v_action := 'revision';
  else
    v_prefix := left(regexp_replace(upper(split_part(v_customer,' ',1)), '[^A-Z]', '', 'g'),5);
    if v_prefix = '' then v_prefix := 'CUST'; end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_company || ':' || v_prefix));
    select coalesce(max(substring(pf.proforma_no from '([0-9]{4})$')::integer),999)
      into v_next
      from public.proformas pf
     where pf.company_code = p_company
       and pf.proforma_no ~ ('^' || v_prefix || '[0-9]{4}$');
    if v_next >= 9999 then
      raise exception 'Proforma number sequence exhausted for prefix %', v_prefix;
    end if;
    v_number := v_prefix || lpad((v_next + 1)::text,4,'0');
    v_root_id := null;
    v_version := 1;
  end if;

  insert into public.proformas (
    company_code, proforma_no, root_proforma_id, version_no, document_action,
    customer_name, customer_tin, customer_address, customer_phone, contact_person,
    delivery_terms, proforma_date, vat_rate, subtotal_before_vat,
    discount_percent, discount_amount, vat_amount, withholding_enabled,
    withholding_rate, withholding_threshold, withholding_amount, grand_total,
    net_payable, company_tin_snapshot, bank_accounts_snapshot, items, notes, terms,
    status, created_by, updated_by
  ) values (
    p_company, v_number, v_root_id, v_version, v_action,
    v_customer, trim(p_payload->>'tin'), nullif(trim(coalesce(p_payload->>'address','')),''),
    nullif(trim(coalesce(p_payload->>'phone','')),''),
    nullif(trim(coalesce(p_payload->>'contactPerson','')),''),
    coalesce(p_payload->>'delivery',''), v_proforma_date, v_vat_rate, v_subtotal,
    v_discount_percent, v_discount_amount, v_vat_amount, v_withholding_enabled,
    v_withholding_rate, v_withholding_threshold, v_withholding_amount, v_grand_total,
    v_net_payable, v_company.tin, v_banks, v_items,
    nullif(coalesce(p_payload->>'notes',''),''), v_terms,
    'draft', (select auth.uid()), (select auth.uid())
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.bokan_save_proforma(text,uuid,jsonb) from public, anon;
grant execute on function public.bokan_save_proforma(text,uuid,jsonb) to authenticated;

-- Seed legal entities with the confirmed TINs. PRIME phone is intentionally
-- NULL pending owner verification; do not copy BlackRock's number by default.
insert into public.companies(code,legal_name,brand_name,tin,address,phone,proforma_title_color,active)
values
  ('PRIME','PRIME Investment Group PLC','PRIME Investment Group','009588209','Addis Ababa, Ethiopia',null,'#8B0000',true),
  ('BLACKROCK','BlackRock Investment PLC','BlackRock Investment','00930533495','Meskel Flower, Addis Ababa, Ethiopia','978 23 48 20','#E17D00',true)
on conflict(code) do nothing;

commit;
