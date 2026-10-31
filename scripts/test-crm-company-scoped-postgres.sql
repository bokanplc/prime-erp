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
create or replace function private.is_active_company_member(p_company_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists (
  select 1 from public.company_memberships m
  where m.company_id=p_company_id and m.user_id=p_user_id and m.is_active
) $$;
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
 ('10000000-0000-0000-0000-000000000004'),
 ('10000000-0000-0000-0000-000000000005');
insert into public.companies(id,name) values
 ('20000000-0000-0000-0000-000000000001','BlackRock'),
 ('20000000-0000-0000-0000-000000000002','Prime');
insert into public.company_memberships(id,company_id,user_id,role,is_active) values
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','manager',true),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','sales',true),
 ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','manager',true),
 ('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004','sales',true),
 ('30000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000005','sales',false);
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

-- Direct reassignment-table UPDATE is forbidden; callers must use the atomic RPC.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
do $direct_assignment$
begin
  begin
    update public.crm_customer_assignments
       set owner_user_id='10000000-0000-0000-0000-000000000003';
    raise exception 'Direct assignment UPDATE unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $direct_assignment$;
reset role;

-- Direct INSERT is forbidden on assignments and events; only the guarded RPC may write them.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
do $direct_assignment_insert$
begin
  begin
    insert into public.crm_customer_assignments
      (company_id, customer_id, owner_user_id, assigned_by)
    values
      ('20000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000001',
       '10000000-0000-0000-0000-000000000002',
       '10000000-0000-0000-0000-000000000001');
    raise exception 'Direct assignment INSERT unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.crm_assignment_events
      (company_id, customer_id, new_owner_user_id, actor_user_id, reason)
    values
      ('20000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000001',
       '10000000-0000-0000-0000-000000000002',
       '10000000-0000-0000-0000-000000000001',
       'Direct event attempt');
    raise exception 'Direct assignment-event INSERT unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $direct_assignment_insert$;
reset role;

-- Verify anon and authenticated table privileges are least-privilege.
do $privilege_checks$
begin
  if has_table_privilege('anon','public.crm_customer_assignments','SELECT')
     or has_table_privilege('anon','public.crm_assignment_events','SELECT')
     or has_table_privilege('anon','public.crm_activities','SELECT') then
    raise exception 'Anonymous CRM table access must be revoked';
  end if;
  if has_table_privilege('authenticated','public.crm_customer_assignments','INSERT')
     or has_table_privilege('authenticated','public.crm_customer_assignments','UPDATE')
     or has_table_privilege('authenticated','public.crm_assignment_events','INSERT')
     or has_table_privilege('authenticated','public.crm_assignment_events','UPDATE') then
    raise exception 'Assignment and history writes must be RPC-only';
  end if;
end $privilege_checks$;

-- Sales owner can create their own task but cannot transfer it to another member.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
insert into public.crm_after_sales_tasks
  (company_id, customer_id, owner_user_id, task_type, created_by)
values
  ('20000000-0000-0000-0000-000000000001',
   '40000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000002',
   'Customer follow-up', '10000000-0000-0000-0000-000000000002');
do $task_transfer$
begin
  begin
    update public.crm_after_sales_tasks
       set owner_user_id='10000000-0000-0000-0000-000000000001';
    raise exception 'Sales user unexpectedly transferred an after-sales task';
  exception when insufficient_privilege then
    null;
  end;
end $task_transfer$;

-- Sales owner cannot transfer their opportunity to a different user.
insert into public.crm_opportunities
  (company_id, customer_id, owner_user_id, product_description, created_by)
values
  ('20000000-0000-0000-0000-000000000001',
   '40000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000002',
   'Plywood supply requirement',
   '10000000-0000-0000-0000-000000000002');
do $opportunity_transfer$
begin
  begin
    update public.crm_opportunities
       set owner_user_id='10000000-0000-0000-0000-000000000001';
    raise exception 'Sales user unexpectedly transferred an opportunity';
  exception when insufficient_privilege then
    null;
  end;
end $opportunity_transfer$;
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

-- Manager cannot assign a customer to an inactive membership.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
do $inactive$
begin
 begin
   perform public.bokan_reassign_customer_owner(
    '20000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000005',
    'Inactive owner attempt'
   );
   raise exception 'Inactive owner assignment unexpectedly succeeded';
 exception when foreign_key_violation then
   null;
 end;
end $inactive$;
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
