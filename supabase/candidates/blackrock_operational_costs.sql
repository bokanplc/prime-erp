-- Candidate only: BlackRock operational cost register and transaction allocation.
-- Do not apply to live Supabase until isolated PostgreSQL tests and browser workflows pass.
-- Forward-only and additive: preserves existing expense columns and records.

begin;

-- Composite keys make every optional source link tenant-safe.
create unique index if not exists expenses_company_id_id_uq
  on public.expenses(company_id, id);
create unique index if not exists supply_shipments_company_id_id_uq
  on public.supply_shipments(company_id, id);
create unique index if not exists delivery_orders_company_id_id_uq
  on public.delivery_orders(company_id, id);

alter table public.expenses
  add column if not exists expense_date date,
  add column if not exists currency_code text not null default 'ETB',
  add column if not exists cost_phase text not null default 'unclassified',
  add column if not exists operational_category text not null default 'other',
  add column if not exists recipient_name text,
  add column if not exists business_purpose text,
  add column if not exists source_reference text,
  add column if not exists review_status text not null default 'pending',
  add column if not exists review_note text;

update public.expenses
set expense_date = coalesce(expense_date, created_at::date),
    business_purpose = coalesce(nullif(business_purpose, ''), nullif(description, ''))
where expense_date is null or business_purpose is null;

alter table public.expenses
  alter column expense_date set default current_date,
  alter column expense_date set not null;

alter table public.expenses
  drop constraint if exists expenses_cost_phase_check,
  add constraint expenses_cost_phase_check
    check (cost_phase in ('procurement','sales_fulfillment','overhead','unclassified')),
  drop constraint if exists expenses_review_status_check,
  add constraint expenses_review_status_check
    check (review_status in ('pending','reviewed','rejected')),
  drop constraint if exists expenses_currency_code_check,
  add constraint expenses_currency_code_check
    check (currency_code ~ '^[A-Z]{3}$'),
  drop constraint if exists expenses_operational_category_check,
  add constraint expenses_operational_category_check
    check (length(trim(operational_category)) between 1 and 80);

create index if not exists expenses_company_date_phase_idx
  on public.expenses(company_id, expense_date desc, cost_phase, review_status);

create table if not exists public.expense_allocations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  expense_id uuid not null,
  purchase_document_id uuid,
  shipment_id uuid,
  product_id uuid,
  sales_document_id uuid,
  delivery_order_id uuid,
  customer_id uuid,
  supplier_id uuid,
  allocated_amount numeric(16,2) not null check (allocated_amount > 0),
  allocation_method text not null default 'manual'
    check (allocation_method in ('manual','quantity','weight','volume','purchase_value','sales_value')),
  basis_quantity numeric(18,4) check (basis_quantity is null or basis_quantity >= 0),
  basis_value numeric(18,4) check (basis_value is null or basis_value >= 0),
  allocation_note text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_allocations_expense_company_fk
    foreign key (company_id, expense_id)
    references public.expenses(company_id, id) on delete restrict,
  constraint expense_allocations_purchase_company_fk
    foreign key (company_id, purchase_document_id)
    references public.purchase_documents(company_id, id) on delete restrict,
  constraint expense_allocations_shipment_company_fk
    foreign key (company_id, shipment_id)
    references public.supply_shipments(company_id, id) on delete restrict,
  constraint expense_allocations_product_company_fk
    foreign key (company_id, product_id)
    references public.products(company_id, id) on delete restrict,
  constraint expense_allocations_sales_company_fk
    foreign key (company_id, sales_document_id)
    references public.sales_documents(company_id, id) on delete restrict,
  constraint expense_allocations_delivery_company_fk
    foreign key (company_id, delivery_order_id)
    references public.delivery_orders(company_id, id) on delete restrict,
  constraint expense_allocations_customer_company_fk
    foreign key (company_id, customer_id)
    references public.customers(company_id, id) on delete restrict,
  constraint expense_allocations_supplier_company_fk
    foreign key (company_id, supplier_id)
    references public.suppliers(company_id, id) on delete restrict,
  constraint expense_allocations_has_target_check
    check (num_nonnulls(purchase_document_id, shipment_id, product_id,
      sales_document_id, delivery_order_id, customer_id, supplier_id) > 0)
);

create index if not exists expense_allocations_company_expense_idx
  on public.expense_allocations(company_id, expense_id);
create index if not exists expense_allocations_company_purchase_idx
  on public.expense_allocations(company_id, purchase_document_id)
  where purchase_document_id is not null;
create index if not exists expense_allocations_company_sales_idx
  on public.expense_allocations(company_id, sales_document_id)
  where sales_document_id is not null;
create index if not exists expense_allocations_company_product_idx
  on public.expense_allocations(company_id, product_id)
  where product_id is not null;

-- Serialize allocations per parent expense so concurrent writes cannot over-allocate.
create or replace function private.enforce_expense_allocation_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
  v_expense_id uuid;
  v_expense_amount numeric(16,2);
  v_existing numeric(16,2);
begin
  if tg_op = 'DELETE' then
    v_company_id := old.company_id;
    v_expense_id := old.expense_id;
  else
    v_company_id := new.company_id;
    v_expense_id := new.expense_id;
  end if;

  if tg_op = 'UPDATE' and
     (new.company_id <> old.company_id or new.expense_id <> old.expense_id) then
    raise exception 'Allocation cannot be moved to another expense or company';
  end if;

  select e.amount into v_expense_amount
  from public.expenses e
  where e.company_id = v_company_id and e.id = v_expense_id
  for update;

  if not found then
    raise exception 'Parent expense not found in the same company';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  if tg_op = 'UPDATE' then
    select coalesce(sum(a.allocated_amount), 0) into v_existing
    from public.expense_allocations a
    where a.company_id = v_company_id and a.expense_id = v_expense_id
      and a.id <> old.id;
  else
    select coalesce(sum(a.allocated_amount), 0) into v_existing
    from public.expense_allocations a
    where a.company_id = v_company_id and a.expense_id = v_expense_id;
  end if;

  if v_existing + new.allocated_amount > v_expense_amount then
    raise exception 'Expense allocations cannot exceed the source expense amount';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists expense_allocations_enforce_limit on public.expense_allocations;
create trigger expense_allocations_enforce_limit
before insert or update or delete on public.expense_allocations
for each row execute function private.enforce_expense_allocation_limit();

alter table public.expense_allocations enable row level security;

drop policy if exists expense_allocations_select_member on public.expense_allocations;
create policy expense_allocations_select_member
on public.expense_allocations for select to authenticated
using (
  private.has_company_membership(company_id)
  and exists (select 1 from public.companies c where c.id = company_id and c.is_active)
);

drop policy if exists expense_allocations_insert_member on public.expense_allocations;
drop policy if exists expense_allocations_insert_manager on public.expense_allocations;
create policy expense_allocations_insert_manager
on public.expense_allocations for insert to authenticated
with check (
  created_by = (select auth.uid())
  and private.has_company_membership(company_id)
  and exists (select 1 from public.companies c where c.id = company_id and c.is_active)
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = expense_allocations.company_id
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
);

drop policy if exists expense_allocations_update_manager on public.expense_allocations;
create policy expense_allocations_update_manager
on public.expense_allocations for update to authenticated
using (
  private.has_company_membership(company_id)
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = expense_allocations.company_id
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
)
with check (
  private.has_company_membership(company_id)
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = expense_allocations.company_id
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
);

drop policy if exists expense_allocations_delete_manager on public.expense_allocations;
create policy expense_allocations_delete_manager
on public.expense_allocations for delete to authenticated
using (
  private.has_company_membership(company_id)
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = expense_allocations.company_id
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
);

revoke all on public.expense_allocations from anon, authenticated;
grant select, insert on public.expense_allocations to authenticated;
grant update, delete on public.expense_allocations to authenticated;

-- Expenses are an operational cost register, not a payment ledger.
-- Keep existing table and records; remove dangerous non-DML grants only.
revoke truncate, references, trigger on public.expenses from authenticated;


-- Immutable allocation change history: corrections remain reviewable.
create table if not exists public.expense_allocation_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  expense_id uuid not null,
  allocation_id uuid not null,
  event_type text not null check (event_type in ('INSERT','UPDATE','DELETE')),
  actor_user_id uuid default auth.uid() references auth.users(id) on delete set null,
  old_record jsonb,
  new_record jsonb,
  occurred_at timestamptz not null default now(),
  constraint expense_allocation_events_expense_company_fk
    foreign key (company_id, expense_id)
    references public.expenses(company_id, id) on delete restrict
);
create index if not exists expense_allocation_events_company_expense_idx
  on public.expense_allocation_events(company_id, expense_id, occurred_at desc);

create or replace function private.audit_expense_allocation_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.expense_allocation_events
      (company_id, expense_id, allocation_id, event_type, actor_user_id, new_record)
    values
      (new.company_id, new.expense_id, new.id, tg_op, (select auth.uid()), to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    insert into public.expense_allocation_events
      (company_id, expense_id, allocation_id, event_type, actor_user_id, old_record, new_record)
    values
      (new.company_id, new.expense_id, new.id, tg_op, (select auth.uid()), to_jsonb(old), to_jsonb(new));
    return new;
  else
    insert into public.expense_allocation_events
      (company_id, expense_id, allocation_id, event_type, actor_user_id, old_record)
    values
      (old.company_id, old.expense_id, old.id, tg_op, (select auth.uid()), to_jsonb(old));
    return old;
  end if;
end;
$$;

drop trigger if exists expense_allocations_audit on public.expense_allocations;
create trigger expense_allocations_audit
after insert or update or delete on public.expense_allocations
for each row execute function private.audit_expense_allocation_change();

alter table public.expense_allocation_events enable row level security;
drop policy if exists expense_allocation_events_select_manager on public.expense_allocation_events;
create policy expense_allocation_events_select_manager
on public.expense_allocation_events for select to authenticated
using (
  private.has_company_membership(company_id)
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = expense_allocation_events.company_id
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
);
revoke all on public.expense_allocation_events from anon, authenticated;
grant select on public.expense_allocation_events to authenticated;

-- One row per expense, including costs that have not yet been allocated.
create or replace view public.expense_allocation_summary
with (security_invoker = true)
as
select
  e.company_id,
  e.id as expense_id,
  e.expense_date,
  e.cost_phase,
  e.operational_category,
  e.amount as source_amount,
  coalesce(sum(a.allocated_amount), 0)::numeric(16,2) as allocated_amount,
  greatest(e.amount - coalesce(sum(a.allocated_amount), 0), 0)::numeric(16,2) as unallocated_amount,
  e.currency_code,
  e.review_status,
  case
    when e.review_status <> 'reviewed' then 'review_pending'
    when coalesce(sum(a.allocated_amount), 0) = 0 then 'unallocated'
    when coalesce(sum(a.allocated_amount), 0) < e.amount then 'partially_allocated'
    else 'fully_allocated'
  end as allocation_status
from public.expenses e
left join public.expense_allocations a
  on a.company_id = e.company_id and a.expense_id = e.id
group by e.company_id, e.id, e.expense_date, e.cost_phase,
         e.operational_category, e.amount, e.currency_code, e.review_status;

grant select on public.expense_allocation_summary to authenticated;

revoke all on function private.enforce_expense_allocation_limit() from public, anon, authenticated;
revoke all on function private.audit_expense_allocation_change() from public, anon, authenticated;

commit;
