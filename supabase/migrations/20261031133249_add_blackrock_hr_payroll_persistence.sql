-- BlackRock-only HR, payroll and employee profile persistence.
create or replace function private.current_company_id()
returns uuid language sql stable security definer set search_path=''
as $$
  select m.company_id
  from public.company_memberships m
  join public.companies c on c.id=m.company_id
  where m.user_id=(select auth.uid()) and m.is_active=true
    and c.is_active=true and c.code='BLACKROCK'
  order by m.created_at limit 1
$$;
revoke all on function private.current_company_id() from public, anon;
grant execute on function private.current_company_id() to authenticated;

create or replace function private.has_company_role(p_company_id uuid,p_roles text[])
returns boolean language sql stable security definer set search_path=''
as $$
  select (select auth.uid()) is not null and exists(
    select 1 from public.company_memberships m
    where m.company_id=p_company_id and m.user_id=(select auth.uid())
      and m.is_active=true and m.role=any(p_roles)
  )
$$;
revoke all on function private.has_company_role(uuid,text[]) from public, anon;
grant execute on function private.has_company_role(uuid,text[]) to authenticated;

alter table public.company_memberships drop constraint if exists company_memberships_role_check;
alter table public.company_memberships add constraint company_memberships_role_check
check(role=any(array['owner','admin','manager','hr','sales','accountant','inventory','staff','viewer']::text[]));

create table public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  full_name text not null default '', email text, department text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create or replace function private.sync_profile_from_membership()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_email text; v_name text;
begin
  select u.email,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),split_part(coalesce(u.email,''),'@',1))
    into v_email,v_name from auth.users u where u.id=new.user_id;
  if v_email is not null then
    insert into public.profiles(id,company_id,full_name,email)
    values(new.user_id,new.company_id,coalesce(v_name,''),v_email)
    on conflict(id) do update set company_id=excluded.company_id,
      full_name=case when excluded.full_name<>'' then excluded.full_name else public.profiles.full_name end,
      email=excluded.email,updated_at=now();
  end if;
  return new;
end
$$;
drop trigger if exists sync_profile_from_company_membership on public.company_memberships;
create trigger sync_profile_from_company_membership
after insert or update of user_id,company_id on public.company_memberships
for each row execute function private.sync_profile_from_membership();

insert into public.profiles(id,company_id,full_name,email)
select u.id,m.company_id,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),split_part(coalesce(u.email,''),'@',1)),u.email
from auth.users u join public.company_memberships m on m.user_id=u.id and m.is_active=true
join public.companies c on c.id=m.company_id and c.code='BLACKROCK' and c.is_active=true
on conflict(id) do update set company_id=excluded.company_id,
  full_name=case when excluded.full_name<>'' then excluded.full_name else public.profiles.full_name end,
  email=excluded.email,updated_at=now();

create table public.bokan_employees(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  full_name text not null, position text not null, department text not null,
  employment_type text not null default 'Full-Time', hire_date date,
  status text not null default 'Active',
  employment_status text generated always as(lower(status)) stored,
  phone text,email text,emergency_contact text,driver_license_no text,education_level text,notes text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);

create table public.bokan_attendance_records(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  employee_id uuid not null references public.bokan_employees(id) on delete restrict,
  employee_name text not null,attendance_date date not null,
  status text not null check(status in('Present','Absent','Late','Leave','Off Day','Remote')),
  notes text,created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(company_id,employee_id,attendance_date)
);

create table public.bokan_leave_requests(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  employee_id uuid references public.bokan_employees(id) on delete set null,
  employee_name text not null,leave_type text not null,start_date date not null,end_date date not null,
  days_requested numeric(8,2) not null default 0 check(days_requested>=0),
  reason text not null default '',status text not null default 'Pending' check(status in('Pending','Approved','Rejected')),
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
  check(end_date>=start_date)
);

create table public.bokan_performance_reviews(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  employee_id uuid references public.bokan_employees(id) on delete set null,
  employee_name text not null,reviewer_name text not null,review_date date not null,
  review_period text,rating text not null,strengths text,areas_for_improvement text,goals text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.bokan_disciplinary_actions(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  employee_id uuid references public.bokan_employees(id) on delete set null,
  employee_name text not null,action_date date not null,issue_type text not null,
  action_taken text not null,issued_by text not null,description text not null,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.bokan_payroll_runs(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  period text,period_start date,period_end date,run_date date not null default current_date,payment_date date,
  status text not null default 'draft' check(status in('draft','prepared','pending_approval','approved','posted','void')),
  total_gross numeric(14,2) not null default 0,total_allowances numeric(14,2) not null default 0,
  total_deductions numeric(14,2) not null default 0,total_net numeric(14,2) not null default 0,notes text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
  check(period_end is null or period_start is null or period_end>=period_start)
);

create table public.bokan_payroll_lines(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  payroll_run_id uuid not null references public.bokan_payroll_runs(id) on delete cascade,
  employee_id uuid references public.bokan_employees(id) on delete set null,
  employee_name text not null,basic_salary numeric(14,2) not null default 0,
  allowances numeric(14,2) not null default 0,overtime_pay numeric(14,2) not null default 0,
  gross_pay numeric(14,2) not null default 0,income_tax numeric(14,2) not null default 0,
  employee_pension numeric(14,2) not null default 0,employer_pension numeric(14,2) not null default 0,
  other_deductions numeric(14,2) not null default 0,net_pay numeric(14,2) not null default 0,
  notes text,created_at timestamptz not null default now()
);

create table public.bokan_payroll_approvals(
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
  payroll_run_id uuid not null references public.bokan_payroll_runs(id) on delete cascade,
  status text not null default 'pending' check(status in('pending','approved','rejected')),
  requested_by uuid default auth.uid() references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,decision_at timestamptz,notes text,
  created_at timestamptz not null default now()
);

create index bokan_employees_company_status_idx on public.bokan_employees(company_id,employment_status);
create index bokan_attendance_company_date_idx on public.bokan_attendance_records(company_id,attendance_date desc);
create index bokan_leave_company_status_idx on public.bokan_leave_requests(company_id,status,start_date);
create index bokan_performance_company_date_idx on public.bokan_performance_reviews(company_id,review_date desc);
create index bokan_disciplinary_company_date_idx on public.bokan_disciplinary_actions(company_id,action_date desc);
create index bokan_payroll_runs_company_period_idx on public.bokan_payroll_runs(company_id,period_start desc);
create index bokan_payroll_lines_company_run_idx on public.bokan_payroll_lines(company_id,payroll_run_id);
create index bokan_payroll_approvals_company_status_idx on public.bokan_payroll_approvals(company_id,status);

create or replace view public.employees with(security_invoker=true) as select * from public.bokan_employees;
create or replace view public.leave_requests with(security_invoker=true) as select * from public.bokan_leave_requests;
create or replace view public.performance_reviews with(security_invoker=true) as select * from public.bokan_performance_reviews;
create or replace view public.disciplinary_actions with(security_invoker=true) as select * from public.bokan_disciplinary_actions;

alter table public.profiles enable row level security;
alter table public.bokan_employees enable row level security;
alter table public.bokan_attendance_records enable row level security;
alter table public.bokan_leave_requests enable row level security;
alter table public.bokan_performance_reviews enable row level security;
alter table public.bokan_disciplinary_actions enable row level security;
alter table public.bokan_payroll_runs enable row level security;
alter table public.bokan_payroll_lines enable row level security;
alter table public.bokan_payroll_approvals enable row level security;

create policy profiles_select_company_members on public.profiles for select to authenticated using(private.has_company_membership(company_id));
create policy profiles_update_self on public.profiles for update to authenticated using(id=(select auth.uid()) and private.has_company_membership(company_id)) with check(id=(select auth.uid()) and private.has_company_membership(company_id));

create policy bokan_employees_select_member on public.bokan_employees for select to authenticated using(private.has_company_membership(company_id));
create policy bokan_employees_insert_hr on public.bokan_employees for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_employees_update_hr on public.bokan_employees for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr'])) with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_employees_delete_manager on public.bokan_employees for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

create policy bokan_attendance_select_hr on public.bokan_attendance_records for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_attendance_insert_hr on public.bokan_attendance_records for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_attendance_update_hr on public.bokan_attendance_records for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr'])) with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_attendance_delete_manager on public.bokan_attendance_records for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

create policy bokan_leave_select_company on public.bokan_leave_requests for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr']) or created_by=(select auth.uid()));
create policy bokan_leave_insert_member on public.bokan_leave_requests for insert to authenticated with check(private.has_company_membership(company_id) and created_by=(select auth.uid()));
create policy bokan_leave_update_owner_or_hr on public.bokan_leave_requests for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr']) or (created_by=(select auth.uid()) and status='Pending')) with check(private.has_company_role(company_id,array['owner','admin','manager','hr']) or (created_by=(select auth.uid()) and status='Pending'));
create policy bokan_leave_delete_manager on public.bokan_leave_requests for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

create policy bokan_performance_select_hr on public.bokan_performance_reviews for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_performance_insert_hr on public.bokan_performance_reviews for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_performance_update_hr on public.bokan_performance_reviews for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr'])) with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_performance_delete_manager on public.bokan_performance_reviews for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

create policy bokan_disciplinary_select_hr on public.bokan_disciplinary_actions for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_disciplinary_insert_hr on public.bokan_disciplinary_actions for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_disciplinary_update_hr on public.bokan_disciplinary_actions for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr'])) with check(private.has_company_role(company_id,array['owner','admin','manager','hr']));
create policy bokan_disciplinary_delete_manager on public.bokan_disciplinary_actions for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

create policy bokan_payroll_runs_select_finance_hr on public.bokan_payroll_runs for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']));
create policy bokan_payroll_runs_insert_finance_hr on public.bokan_payroll_runs for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']));
create policy bokan_payroll_runs_update_finance on public.bokan_payroll_runs for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','accountant'])) with check(private.has_company_role(company_id,array['owner','admin','manager','accountant']));
create policy bokan_payroll_runs_delete_manager on public.bokan_payroll_runs for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

create policy bokan_payroll_lines_select_finance_hr on public.bokan_payroll_lines for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']));
create policy bokan_payroll_lines_insert_finance_hr on public.bokan_payroll_lines for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']));
create policy bokan_payroll_lines_update_finance on public.bokan_payroll_lines for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','accountant'])) with check(private.has_company_role(company_id,array['owner','admin','manager','accountant']));
create policy bokan_payroll_lines_delete_manager on public.bokan_payroll_lines for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

create policy bokan_payroll_approvals_select_finance_hr on public.bokan_payroll_approvals for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']));
create policy bokan_payroll_approvals_insert_finance_hr on public.bokan_payroll_approvals for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']));
create policy bokan_payroll_approvals_update_finance on public.bokan_payroll_approvals for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','accountant'])) with check(private.has_company_role(company_id,array['owner','admin','manager','accountant']));
create policy bokan_payroll_approvals_delete_manager on public.bokan_payroll_approvals for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

grant select,insert,update,delete on public.profiles to authenticated;
grant select,insert,update,delete on public.bokan_employees,public.bokan_attendance_records,public.bokan_leave_requests,
  public.bokan_performance_reviews,public.bokan_disciplinary_actions,public.bokan_payroll_runs,
  public.bokan_payroll_lines,public.bokan_payroll_approvals to authenticated;
grant select,insert,update,delete on public.employees,public.leave_requests,public.performance_reviews,public.disciplinary_actions to authenticated;
revoke all on public.profiles,public.bokan_employees,public.bokan_attendance_records,public.bokan_leave_requests,
  public.bokan_performance_reviews,public.bokan_disciplinary_actions,public.bokan_payroll_runs,
  public.bokan_payroll_lines,public.bokan_payroll_approvals,public.employees,public.leave_requests,
  public.performance_reviews,public.disciplinary_actions from anon;
