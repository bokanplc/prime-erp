-- Applied to Supabase project kafiwnuynjemufnankvi on 2026-10-31 as migration
-- 20261031081151_add_company_scoped_crm_foundation.
-- Retained under candidates while the repository source-parity guard is updated.
-- Extends the existing public.customers / companies / company_memberships model.

begin;

create table if not exists public.crm_customer_assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  customer_id uuid not null,
  owner_user_id uuid not null,
  assigned_by uuid not null default auth.uid(),
  assigned_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crm_customer_assignments_company_customer_key unique (company_id, customer_id),
  constraint crm_customer_assignments_customer_fk
    foreign key (company_id, customer_id)
    references public.customers(company_id, id) on delete cascade,
  constraint crm_customer_assignments_owner_membership_fk
    foreign key (company_id, owner_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict,
  constraint crm_customer_assignments_actor_membership_fk
    foreign key (company_id, assigned_by)
    references public.company_memberships(company_id, user_id) on delete restrict
);

create table if not exists public.crm_assignment_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  customer_id uuid not null,
  old_owner_user_id uuid,
  new_owner_user_id uuid not null,
  actor_user_id uuid not null default auth.uid(),
  reason text not null check (length(btrim(reason)) between 1 and 2000),
  created_at timestamptz not null default now(),
  constraint crm_assignment_events_customer_fk
    foreign key (company_id, customer_id)
    references public.customers(company_id, id) on delete cascade,
  constraint crm_assignment_events_old_owner_fk
    foreign key (company_id, old_owner_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict,
  constraint crm_assignment_events_new_owner_fk
    foreign key (company_id, new_owner_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict,
  constraint crm_assignment_events_actor_fk
    foreign key (company_id, actor_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict
);

create table if not exists public.crm_activities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  customer_id uuid not null,
  actor_user_id uuid not null default auth.uid(),
  assigned_user_id uuid,
  activity_type text not null check (length(btrim(activity_type)) between 1 and 80),
  activity_at timestamptz not null default now(),
  notes text not null default '' check (length(notes) <= 10000),
  customer_feedback text not null default '' check (length(customer_feedback) <= 5000),
  next_action_type text check (next_action_type is null or length(next_action_type) <= 120),
  next_action_date date,
  escalated boolean not null default false,
  escalate_reason text check (escalate_reason is null or length(escalate_reason) <= 500),
  escalate_note text check (escalate_note is null or length(escalate_note) <= 5000),
  created_at timestamptz not null default now(),
  constraint crm_activities_customer_fk
    foreign key (company_id, customer_id)
    references public.customers(company_id, id) on delete cascade,
  constraint crm_activities_actor_membership_fk
    foreign key (company_id, actor_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict,
  constraint crm_activities_assignee_membership_fk
    foreign key (company_id, assigned_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict
);

create table if not exists public.crm_opportunities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  customer_id uuid not null,
  owner_user_id uuid not null default auth.uid(),
  product_description text not null check (length(btrim(product_description)) between 1 and 500),
  estimated_quantity numeric(18,3) not null default 0 check (estimated_quantity >= 0),
  estimated_value numeric(18,2) not null default 0 check (estimated_value >= 0),
  currency_code text not null default 'ETB' check (currency_code ~ '^[A-Z]{3}$'),
  required_date date,
  stage text not null default 'lead'
    check (stage in ('lead','qualified','quotation','negotiation','won','lost','on_hold')),
  next_action text,
  next_action_date date,
  competitor text check (competitor is null or length(competitor) <= 300),
  notes text not null default '' check (length(notes) <= 10000),
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crm_opportunities_customer_fk
    foreign key (company_id, customer_id)
    references public.customers(company_id, id) on delete cascade,
  constraint crm_opportunities_owner_membership_fk
    foreign key (company_id, owner_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict,
  constraint crm_opportunities_creator_membership_fk
    foreign key (company_id, created_by)
    references public.company_memberships(company_id, user_id) on delete restrict
);

create table if not exists public.crm_after_sales_tasks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  customer_id uuid not null,
  owner_user_id uuid,
  task_type text not null check (length(btrim(task_type)) between 1 and 200),
  notes text not null default '' check (length(notes) <= 10000),
  due_date date,
  status text not null default 'open' check (status in ('open','completed','cancelled')),
  completed_at timestamptz,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crm_after_sales_tasks_customer_fk
    foreign key (company_id, customer_id)
    references public.customers(company_id, id) on delete cascade,
  constraint crm_after_sales_tasks_owner_membership_fk
    foreign key (company_id, owner_user_id)
    references public.company_memberships(company_id, user_id) on delete restrict,
  constraint crm_after_sales_tasks_creator_membership_fk
    foreign key (company_id, created_by)
    references public.company_memberships(company_id, user_id) on delete restrict,
  constraint crm_after_sales_tasks_completion_check
    check ((status = 'completed' and completed_at is not null) or status <> 'completed')
);

create index if not exists crm_assignment_events_company_customer_created_idx
  on public.crm_assignment_events(company_id, customer_id, created_at desc);
create index if not exists crm_activities_company_customer_activity_idx
  on public.crm_activities(company_id, customer_id, activity_at desc);
create index if not exists crm_activities_company_next_action_idx
  on public.crm_activities(company_id, next_action_date)
  where next_action_date is not null;
create index if not exists crm_opportunities_company_stage_next_date_idx
  on public.crm_opportunities(company_id, stage, next_action_date);
create index if not exists crm_after_sales_tasks_company_status_due_idx
  on public.crm_after_sales_tasks(company_id, status, due_date);

alter table public.crm_customer_assignments enable row level security;
alter table public.crm_assignment_events enable row level security;
alter table public.crm_activities enable row level security;
alter table public.crm_opportunities enable row level security;
alter table public.crm_after_sales_tasks enable row level security;

-- Membership existence alone is insufficient: disabled memberships must not
-- receive new assignments or act on CRM records.
create or replace function private.is_active_company_member(
  p_company_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.company_memberships m
     where m.company_id = p_company_id
       and m.user_id = p_user_id
       and m.is_active
  );
$$;
revoke all on function private.is_active_company_member(uuid, uuid) from public, anon;
grant execute on function private.is_active_company_member(uuid, uuid) to authenticated;

create policy crm_assignments_company_read on public.crm_customer_assignments
  for select to authenticated
  using ((select private.has_company_membership(company_id)));
create policy crm_assignments_manager_insert on public.crm_customer_assignments
  for insert to authenticated
  with check ((select private.can_manage_company(company_id))
    and assigned_by = (select auth.uid())
    and (select private.is_active_company_member(company_id, owner_user_id))
    and (select private.is_active_company_member(company_id, assigned_by)));
-- Assignment changes must use the atomic reassignment RPC; direct UPDATE is intentionally absent.

create policy crm_assignment_events_company_read on public.crm_assignment_events
  for select to authenticated
  using ((select private.has_company_membership(company_id)));
create policy crm_assignment_events_manager_insert on public.crm_assignment_events
  for insert to authenticated
  with check ((select private.can_manage_company(company_id))
    and actor_user_id = (select auth.uid())
    and (select private.is_active_company_member(company_id, new_owner_user_id))
    and (select private.is_active_company_member(company_id, actor_user_id)));
-- No UPDATE or DELETE policy: assignment history is append-only.

create policy crm_activities_company_read on public.crm_activities
  for select to authenticated
  using ((select private.has_company_membership(company_id)));
create policy crm_activities_member_insert on public.crm_activities
  for insert to authenticated
  with check ((select private.has_company_membership(company_id))
    and actor_user_id = (select auth.uid())
    and (select private.is_active_company_member(company_id, actor_user_id)));
-- Activity corrections/deletions require a separately reviewed audit workflow.

create policy crm_opportunities_company_read on public.crm_opportunities
  for select to authenticated
  using ((select private.has_company_membership(company_id)));
create policy crm_opportunities_member_insert on public.crm_opportunities
  for insert to authenticated
  with check ((select private.has_company_membership(company_id))
    and created_by = (select auth.uid())
    and owner_user_id = (select auth.uid()));
create policy crm_opportunities_owner_update on public.crm_opportunities
  for update to authenticated
  using ((select private.has_company_membership(company_id))
    and (owner_user_id = (select auth.uid()) or (select private.can_manage_company(company_id))))
  with check ((select private.has_company_membership(company_id))
    and (owner_user_id = (select auth.uid()) or (select private.can_manage_company(company_id)))
    and (select private.is_active_company_member(company_id, owner_user_id)));

create policy crm_after_sales_company_read on public.crm_after_sales_tasks
  for select to authenticated
  using ((select private.has_company_membership(company_id)));
create policy crm_after_sales_member_insert on public.crm_after_sales_tasks
  for insert to authenticated
  with check ((select private.has_company_membership(company_id))
    and created_by = (select auth.uid())
    and (select private.is_active_company_member(company_id, created_by))
    and (owner_user_id is null or (select private.is_active_company_member(company_id, owner_user_id))));
create policy crm_after_sales_owner_update on public.crm_after_sales_tasks
  for update to authenticated
  using ((select private.has_company_membership(company_id))
    and (owner_user_id = (select auth.uid()) or (select private.can_manage_company(company_id))))
  with check ((select private.has_company_membership(company_id))
    and (owner_user_id = (select auth.uid()) or (select private.can_manage_company(company_id)))
    and (owner_user_id is null or (select private.is_active_company_member(company_id, owner_user_id))));

grant select, insert on public.crm_customer_assignments to authenticated;
grant select, insert on public.crm_assignment_events to authenticated;
grant select, insert on public.crm_activities to authenticated;
grant select, insert on public.crm_opportunities to authenticated;
grant update (product_description, estimated_quantity, estimated_value, currency_code, required_date, stage, next_action, next_action_date, competitor, notes, owner_user_id) on public.crm_opportunities to authenticated;
grant select, insert on public.crm_after_sales_tasks to authenticated;
grant update (task_type, notes, due_date, status, completed_at, owner_user_id) on public.crm_after_sales_tasks to authenticated;

create or replace function public.bokan_reassign_customer_owner(
  p_company_id uuid,
  p_customer_id uuid,
  p_new_owner_user_id uuid,
  p_reason text
)
returns public.crm_customer_assignments
language plpgsql
security definer
set search_path = ''
as $reassign$
declare
  v_old_owner uuid;
  v_result public.crm_customer_assignments;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if not (select private.can_manage_company(p_company_id)) then
    raise exception 'Company manager permission required' using errcode = '42501';
  end if;
  if p_reason is null or length(btrim(p_reason)) = 0 then
    raise exception 'Reassignment reason is required' using errcode = '22023';
  end if;

  -- Serialize concurrent reassignment attempts without requiring UPDATE rights on customers.
  -- The advisory lock is scoped to this company/customer pair; the following lookup remains read-only.
  perform pg_advisory_xact_lock(
    hashtextextended(p_company_id::text || ':' || p_customer_id::text, 0)
  );
  perform 1
    from public.customers c
   where c.company_id = p_company_id and c.id = p_customer_id;
  if not found then
    raise exception 'Customer not found in selected company' using errcode = '23503';
  end if;

  if not (select private.is_active_company_member(p_company_id, p_new_owner_user_id)) then
    raise exception 'New owner must be an active company member' using errcode = '23503';
  end if;

  -- The advisory lock above serializes this read/update pair without granting table UPDATE.
  select a.owner_user_id into v_old_owner
    from public.crm_customer_assignments a
   where a.company_id = p_company_id and a.customer_id = p_customer_id;

  insert into public.crm_customer_assignments
    (company_id, customer_id, owner_user_id, assigned_by, assigned_at, updated_at)
  values
    (p_company_id, p_customer_id, p_new_owner_user_id, (select auth.uid()), now(), now())
  on conflict (company_id, customer_id) do update
    set owner_user_id = excluded.owner_user_id,
        assigned_by = excluded.assigned_by,
        assigned_at = excluded.assigned_at,
        updated_at = now()
  returning * into v_result;

  insert into public.crm_assignment_events
    (company_id, customer_id, old_owner_user_id, new_owner_user_id, actor_user_id, reason)
  values
    (p_company_id, p_customer_id, v_old_owner, p_new_owner_user_id, (select auth.uid()), btrim(p_reason));

  return v_result;
end;
$reassign$;

revoke all on function public.bokan_reassign_customer_owner(uuid, uuid, uuid, text) from public, anon;
grant execute on function public.bokan_reassign_customer_owner(uuid, uuid, uuid, text) to authenticated;

commit;
