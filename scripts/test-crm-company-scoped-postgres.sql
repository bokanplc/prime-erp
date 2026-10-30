\set ON_ERROR_STOP on
\! createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" crm_isolated
\connect crm_isolated
create schema if not exists auth;
create schema if not exists private;
create table auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid
language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create table public.companies (id uuid primary key, name text not null);
create table public.company_memberships (
  id uuid primary key,
  company_id uuid not null references public.companies(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('owner','admin','manager','sales','accountant','inventory','staff','viewer')),
  is_active boolean not null default true,
  unique(company_id,id),
  unique(company_id,user_id)
);
create table public.customers (
  id uuid primary key,
  company_id uuid not null references public.companies(id),
  name text not null,
  unique(company_id,id)
);

create or replace function private.has_company_membership(p_company_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists (
   select 1 from public.company_memberships m
    where m.company_id=p_company_id and m.user_id=(select auth.uid()) and m.is_active
 )
$$;
create or replace function private.can_manage_company(p_company_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists (
   select 1 from public.company_memberships m
    where m.company_id=p_company_id and m.user_id=(select auth.uid())
      and m.is_active and m.role in ('owner','admin','manager')
 )
$$;

insert into auth.users(id) values
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002'),
 ('10000000-0000-0000-0000-000000000003'),
 ('10000000-0000-0000-0000-000000000004');
insert into public.companies(id,name) values
 ('20000000-0000-0000-0000-000000000001','BlackRock'),
 ('20000000-0000-0000-0000-000000000002','Prime');
insert into public.company_memberships(id,company_id,user_id,role) values
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','manager'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','sales'),
 ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','manager'),
 ('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004','sales');
insert into public.customers(id,company_id,name) values
 ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','BlackRock Customer'),
 ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Prime Customer');

do $roles$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
end $roles$;
grant usage on schema public, auth, private to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant execute on function private.has_company_membership(uuid) to authenticated;
grant execute on function private.can_manage_company(uuid) to authenticated;
grant select on public.company_memberships to authenticated;
grant select on public.customers to authenticated;
grant select on public.companies to authenticated;

\ir ../supabase/candidates/crm_company_scoped_v1.sql

-- Manager A can assign a customer to an active salesperson in the same company.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
select public.bokan_reassign_customer_owner(
 '20000000-0000-0000-0000-000000000001',
 '40000000-0000-0000-0000-000000000001',
 '10000000-0000-0000-0000-000000000002',
 'Initial territory assignment'
);
reset role;

-- Verify assignment and event were committed together.
do $$
begin
 if (select count(*) from public.crm_customer_assignments) <> 1 then
   raise exception 'Expected exactly one current assignment';
 end if;
 if (select count(*) from public.crm_assignment_events) <> 1 then
   raise exception 'Expected exactly one assignment event';
 end if;
end $$;

-- Sales user cannot invoke manager-only reassignment.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
do $$
begin
 begin
   perform public.bokan_reassign_customer_owner(
    '20000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    'Should be denied'
   );
   raise exception 'Sales user unexpectedly reassigned a customer';
 exception when insufficient_privilege then
   null;
 end;
end $$;
reset role;

-- Company A manager cannot assign a company B customer or owner.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
do $$
begin
 begin
   perform public.bokan_reassign_customer_owner(
    '20000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000004',
    'Cross-company attempt'
   );
   raise exception 'Cross-company reassignment unexpectedly succeeded';
 exception when foreign_key_violation or insufficient_privilege then
   null;
 end;
end $$;
reset role;

-- Company B cannot see company A CRM rows.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',false);
do $$
begin
 if (select count(*) from public.crm_customer_assignments) <> 0 then
   raise exception 'Company B can see Company A assignment';
 end if;
 if (select count(*) from public.crm_assignment_events) <> 0 then
   raise exception 'Company B can see Company A assignment history';
 end if;
end $$;
reset role;

-- History must not be mutable by authenticated clients.\n-- This test runs in an isolated PostgreSQL service, never against live company data.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
do $$
begin
 begin
   update public.crm_assignment_events set reason='tampered';
   raise exception 'Assignment history unexpectedly mutable';
 exception when insufficient_privilege then
   null;
 end;
end $$;
reset role;

select 'CRM company-scope and reassignment smoke tests passed' as result;
