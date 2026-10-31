\set ON_ERROR_STOP on
create extension if not exists pgcrypto;
create schema auth;
create schema private;
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create table public.companies(
  id uuid primary key, code text not null unique, is_active boolean not null default true
);
create table public.company_memberships(
  company_id uuid not null references public.companies(id), user_id uuid not null,
  role text not null, is_active boolean not null default true, created_at timestamptz not null default now()
);
insert into public.companies(id,code) values
('11111111-1111-4111-8111-111111111111','BLACKROCK'),
('22222222-2222-4222-8222-222222222222','OTHER');
insert into public.company_memberships(company_id,user_id,role) values
('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','hr');

create function private.current_company_id() returns uuid language sql stable security definer set search_path='' as $$
  select m.company_id from public.company_memberships m
  join public.companies c on c.id=m.company_id
  where m.user_id=(select auth.uid()) and m.is_active and c.is_active and c.code='BLACKROCK'
  order by m.created_at limit 1
$$;
create function private.has_company_role(p_company_id uuid,p_roles text[]) returns boolean
language sql stable security definer set search_path='' as $$
  select (select auth.uid()) is not null and exists(
    select 1 from public.company_memberships m
    where m.company_id=p_company_id and m.user_id=(select auth.uid())
      and m.is_active and m.role=any(p_roles)
  )
$$;

create table public.employees(id uuid primary key default gen_random_uuid(),company_id uuid,created_by uuid,full_name text);
create table public.leave_requests(id uuid primary key default gen_random_uuid(),company_id uuid,created_by uuid,employee_name text);
create table public.performance_reviews(id uuid primary key default gen_random_uuid(),company_id uuid,created_by uuid,employee_name text);
create table public.disciplinary_actions(id uuid primary key default gen_random_uuid(),company_id uuid,created_by uuid,employee_name text);

grant usage on schema public,auth,private to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function private.current_company_id() to authenticated;
grant execute on function private.has_company_role(uuid,text[]) to authenticated;

\i supabase/migrations/20261031150000_scope_legacy_hr_tables_to_blackrock.sql

do $$
declare t text;
begin
  foreach t in array array['employees','leave_requests','performance_reviews','disciplinary_actions'] loop
    if not (select relrowsecurity from pg_class where oid=('public.'||t)::regclass) then
      raise exception 'RLS is not enabled for %',t;
    end if;
    if not exists(select 1 from pg_attribute where attrelid=('public.'||t)::regclass and attname='company_id' and attnotnull) then
      raise exception 'company_id must be NOT NULL for %',t;
    end if;
  end loop;
end $$;

grant usage on schema public to authenticated;
set role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false);
insert into public.employees(full_name,created_by) values('Authorized HR employee',auth.uid());
insert into public.leave_requests(employee_name,created_by) values('Authorized HR employee',auth.uid());
insert into public.performance_reviews(employee_name,created_by) values('Authorized HR employee',auth.uid());
insert into public.disciplinary_actions(employee_name,created_by) values('Authorized HR employee',auth.uid());

do $$
begin
  if (select count(*) from public.employees where company_id='11111111-1111-4111-8111-111111111111')<>1 then raise exception 'BlackRock HR insert/default scope failed.'; end if;
  if (select count(*) from public.leave_requests)<>1 then raise exception 'Leave request insert failed.'; end if;
  if (select count(*) from public.performance_reviews)<>1 then raise exception 'Performance review insert failed.'; end if;
  if (select count(*) from public.disciplinary_actions)<>1 then raise exception 'Disciplinary action insert failed.'; end if;
end $$;

select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false);
do $$
begin
  if (select count(*) from public.employees)<>0 then raise exception 'A non-member can read HR employee data.'; end if;
  begin
    insert into public.employees(full_name,created_by) values('Unauthorized employee',auth.uid());
    raise exception 'A non-member unexpectedly inserted an HR employee.';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.employees(company_id,full_name,created_by)
    values('22222222-2222-4222-8222-222222222222','Cross-company employee',auth.uid());
    raise exception 'A non-member unexpectedly inserted into another company.';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

do $$
begin
  if has_table_privilege('anon','public.employees','SELECT') then raise exception 'anon retains HR table access.'; end if;
  if has_table_privilege('anon','public.leave_requests','SELECT') then raise exception 'anon retains leave table access.'; end if;
end $$;
select 'PASS: legacy HR tables are BlackRock-scoped, RLS-protected, and inaccessible to non-members/anon.' as result;
