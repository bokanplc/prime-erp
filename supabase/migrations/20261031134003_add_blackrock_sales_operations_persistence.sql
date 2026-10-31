-- Remaining V6.7 sales, field-operations, stock-log and support persistence.
alter table public.customers add column if not exists customer_name text generated always as (name) stored;
alter table public.customers add column if not exists assigned_rep uuid references auth.users(id) on delete set null;
create index if not exists customers_company_assigned_rep_idx on public.customers(company_id,assigned_rep);
alter table public.crm_activities alter column company_id set default private.current_company_id();
alter table public.profiles add column if not exists role text;

create or replace function private.sync_profile_from_membership()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_email text; v_name text;
begin
 select u.email,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),split_part(coalesce(u.email,''),'@',1))
 into v_email,v_name from auth.users u where u.id=new.user_id;
 if v_email is not null then
  insert into public.profiles(id,company_id,full_name,email,role)
  values(new.user_id,new.company_id,coalesce(v_name,''),v_email,new.role)
  on conflict(id) do update set company_id=excluded.company_id,
   full_name=case when excluded.full_name<>'' then excluded.full_name else public.profiles.full_name end,
   email=excluded.email,role=excluded.role,updated_at=now();
 end if;
 return new;
end $$;
update public.profiles p set role=m.role,company_id=m.company_id,updated_at=now()
from public.company_memberships m where m.user_id=p.id and m.is_active=true and m.company_id=p.company_id;

create or replace function private.sync_customer_assigned_rep()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if tg_op='DELETE' then
  update public.customers set assigned_rep=null where id=old.customer_id and company_id=old.company_id;
  return old;
 end if;
 update public.customers set assigned_rep=new.owner_user_id where id=new.customer_id and company_id=new.company_id;
 return new;
end $$;
drop trigger if exists sync_customer_assigned_rep on public.crm_customer_assignments;
create trigger sync_customer_assigned_rep after insert or update of customer_id,company_id,owner_user_id or delete
on public.crm_customer_assignments for each row execute function private.sync_customer_assigned_rep();
update public.customers c set assigned_rep=a.owner_user_id from public.crm_customer_assignments a
where a.customer_id=c.id and a.company_id=c.company_id;

create or replace view public.customer_logs with(security_invoker=true) as
select id,company_id,customer_id,actor_user_id as sales_rep,status,activity_type,notes,customer_feedback,
deal_value,units_sold,product_type,next_action_type,next_action_date,escalated,escalate_reason,
escalate_note,activity_at as created_at from public.crm_activities;

create table public.customer_billings(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 billing_no text not null,customer_name text not null,customer_address text,billing_date date not null default current_date,
 deliveries jsonb not null default '[]'::jsonb,vat_percent numeric(7,3) not null default 0,notes text,
 subtotal numeric(14,2) not null default 0,vat_amount numeric(14,2) not null default 0,total numeric(14,2) not null default 0,
 created_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now(),
 unique(company_id,billing_no));
create table public.expenses(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 category text not null,amount numeric(14,2) not null check(amount>=0),description text not null default '',location text,paid_by text,
 created_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.notifications(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 type text not null,message text not null,meta jsonb,"read" boolean not null default false,
 created_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now());
create table public.sales_targets(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 employee_name text not null,period text not null,target_quantity numeric(14,2) not null default 0,rep_level text,manager_name text,senior_name text,
 commission_type text,commission_rate numeric(12,4) not null default 0,flat_rate_product_type text,flat_rate_amount numeric(14,2) not null default 0,
 flat_rate_unit_label text,created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.trip_plans(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 employee_name text not null,departure_date date not null,return_date date,destination text not null,transportation_mode text,purpose text,product_type text,
 planned_visits jsonb not null default '[]'::jsonb,notes text,is_late_exception boolean not null default false,late_explanation text,
 created_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),check(return_date is null or return_date>=departure_date));
create table public.per_diem_requests(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 trip_plan_id uuid not null references public.trip_plans(id) on delete restrict,employee_name text not null,position text,
 request_date date not null default current_date,destination text not null,distance_km numeric(10,2) not null default 0,
 overnight boolean not null default false,departure_date date,return_date date,transport_cost numeric(14,2) not null default 0,
 purpose text,product_type text,nights numeric(8,2) not null default 0,meal_rate numeric(14,2) not null default 0,
 room_rate numeric(14,2) not null default 0,total_requested numeric(14,2) not null default 0,notes text,
 status text not null default 'Pending' check(status in('Pending','Approved','Rejected','Paid')),
 created_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.visit_reports(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 employee_name text not null,visit_date date not null,customer_name text not null,contact_person text,location text,purpose text,product_type text,
 outcome text,next_steps text,follow_up_date date,is_late boolean not null default false,late_explanation text,
 created_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.stock_entries(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 entry_type text not null check(entry_type in('purchase','sale')),item_name text not null,quantity numeric(14,3) not null check(quantity>0),
 unit_price numeric(14,2) not null default 0 check(unit_price>=0),total numeric(16,2) generated always as(quantity*unit_price) stored,
 location text,notes text,created_by uuid default auth.uid() references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.stock_ledger(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 entry_date date not null,purchased_by text,factory_qty numeric(14,3) not null default 0,purchase_price numeric(14,2) not null default 0,
 shipped_kolfe_qty numeric(14,3) not null default 0,kolfe_to_mes_qty numeric(14,3) not null default 0,
 sales_kolfe_qty numeric(14,3) not null default 0,sales_mes_qty numeric(14,3) not null default 0,sold_by text,sale_price numeric(14,2) not null default 0,
 notes text,created_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.documents(
 id uuid primary key default gen_random_uuid(),company_id uuid not null default private.current_company_id() references public.companies(id) on delete cascade,
 category text not null,title text not null,file_path text not null,file_url text,
 uploaded_by uuid default auth.uid() references auth.users(id) on delete set null,created_at timestamptz not null default now());

create index customer_billings_company_date_idx on public.customer_billings(company_id,billing_date desc);
create index expenses_company_created_idx on public.expenses(company_id,created_at desc);
create index notifications_company_created_idx on public.notifications(company_id,created_at desc);
create index sales_targets_company_period_idx on public.sales_targets(company_id,period);
create index trip_plans_company_departure_idx on public.trip_plans(company_id,departure_date desc);
create index per_diem_company_status_idx on public.per_diem_requests(company_id,status,request_date desc);
create index visit_reports_company_date_idx on public.visit_reports(company_id,visit_date desc);
create index stock_entries_company_created_idx on public.stock_entries(company_id,created_at desc);
create index stock_ledger_company_date_idx on public.stock_ledger(company_id,entry_date desc);
create index documents_company_category_idx on public.documents(company_id,category,created_at desc);

alter table public.customer_billings enable row level security;
alter table public.expenses enable row level security;
alter table public.notifications enable row level security;
alter table public.sales_targets enable row level security;
alter table public.trip_plans enable row level security;
alter table public.per_diem_requests enable row level security;
alter table public.visit_reports enable row level security;
alter table public.stock_entries enable row level security;
alter table public.stock_ledger enable row level security;
alter table public.documents enable row level security;

create policy customer_billings_select_member on public.customer_billings for select to authenticated using(private.has_company_membership(company_id));
create policy customer_billings_insert_sales_finance on public.customer_billings for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','sales','accountant']));
create policy customer_billings_delete_manager on public.customer_billings for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));
create policy expenses_select_member on public.expenses for select to authenticated using(private.has_company_membership(company_id));
create policy expenses_insert_member on public.expenses for insert to authenticated with check(private.has_company_membership(company_id) and created_by=(select auth.uid()));
create policy expenses_update_finance on public.expenses for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','accountant'])) with check(private.has_company_role(company_id,array['owner','admin','manager','accountant']));
create policy expenses_delete_finance on public.expenses for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','accountant']));
create policy notifications_select_member on public.notifications for select to authenticated using(private.has_company_membership(company_id));
create policy notifications_insert_member on public.notifications for insert to authenticated with check(private.has_company_membership(company_id) and created_by=(select auth.uid()));
create policy notifications_update_manager on public.notifications for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager'])) with check(private.has_company_role(company_id,array['owner','admin','manager']));
create policy sales_targets_select_member on public.sales_targets for select to authenticated using(private.has_company_membership(company_id));
create policy sales_targets_insert_manager on public.sales_targets for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager']));
create policy sales_targets_update_manager on public.sales_targets for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager'])) with check(private.has_company_role(company_id,array['owner','admin','manager']));
create policy sales_targets_delete_manager on public.sales_targets for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));
create policy trip_plans_select_member on public.trip_plans for select to authenticated using(private.has_company_membership(company_id));
create policy trip_plans_insert_member on public.trip_plans for insert to authenticated with check(private.has_company_membership(company_id) and created_by=(select auth.uid()));
create policy trip_plans_update_owner_manager on public.trip_plans for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']) or created_by=(select auth.uid())) with check(private.has_company_role(company_id,array['owner','admin','manager']) or created_by=(select auth.uid()));
create policy trip_plans_delete_manager on public.trip_plans for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));
create policy per_diem_select_owner_hr on public.per_diem_requests for select to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']) or created_by=(select auth.uid()));
create policy per_diem_insert_member on public.per_diem_requests for insert to authenticated with check(private.has_company_membership(company_id) and created_by=(select auth.uid()));
create policy per_diem_update_owner_hr on public.per_diem_requests for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']) or (created_by=(select auth.uid()) and status='Pending')) with check(private.has_company_role(company_id,array['owner','admin','manager','hr','accountant']) or (created_by=(select auth.uid()) and status='Pending'));
create policy per_diem_delete_manager on public.per_diem_requests for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));
create policy visit_reports_select_member on public.visit_reports for select to authenticated using(private.has_company_membership(company_id));
create policy visit_reports_insert_member on public.visit_reports for insert to authenticated with check(private.has_company_membership(company_id) and created_by=(select auth.uid()));
create policy visit_reports_update_owner_manager on public.visit_reports for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']) or created_by=(select auth.uid())) with check(private.has_company_role(company_id,array['owner','admin','manager']) or created_by=(select auth.uid()));
create policy visit_reports_delete_manager on public.visit_reports for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));
create policy stock_entries_select_member on public.stock_entries for select to authenticated using(private.has_company_membership(company_id));
create policy stock_entries_insert_inventory on public.stock_entries for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','inventory']));
create policy stock_entries_update_inventory on public.stock_entries for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','inventory'])) with check(private.has_company_role(company_id,array['owner','admin','manager','inventory']));
create policy stock_entries_delete_manager on public.stock_entries for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));
create policy stock_ledger_select_member on public.stock_ledger for select to authenticated using(private.has_company_membership(company_id));
create policy stock_ledger_insert_inventory on public.stock_ledger for insert to authenticated with check(private.has_company_role(company_id,array['owner','admin','manager','inventory']));
create policy stock_ledger_update_inventory on public.stock_ledger for update to authenticated using(private.has_company_role(company_id,array['owner','admin','manager','inventory'])) with check(private.has_company_role(company_id,array['owner','admin','manager','inventory']));
create policy stock_ledger_delete_manager on public.stock_ledger for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));
create policy documents_select_member on public.documents for select to authenticated using(private.has_company_membership(company_id));
create policy documents_insert_member on public.documents for insert to authenticated with check(private.has_company_membership(company_id) and uploaded_by=(select auth.uid()));
create policy documents_delete_manager on public.documents for delete to authenticated using(private.has_company_role(company_id,array['owner','admin','manager']));

grant select,insert,update,delete on public.customer_billings,public.expenses,public.notifications,public.sales_targets,public.trip_plans,
 public.per_diem_requests,public.visit_reports,public.stock_entries,public.stock_ledger,public.documents to authenticated;
grant select,insert on public.customer_logs to authenticated;
revoke all on public.customer_billings,public.expenses,public.notifications,public.sales_targets,public.trip_plans,
 public.per_diem_requests,public.visit_reports,public.stock_entries,public.stock_ledger,public.documents,public.customer_logs from anon;
