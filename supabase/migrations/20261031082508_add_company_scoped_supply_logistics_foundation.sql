-- BOKAN ERP V6.7: company-scoped Supply & Logistics control records.
-- This slice persists the current V6.7 inbound shipment and delivery-control forms.
-- It intentionally does not create inventory movements or post purchasing documents;
-- those remain governed by the existing atomic purchasing/inventory workflows.

create table public.supply_shipments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  shipment_no text not null,
  factory_name text not null check (length(btrim(factory_name)) > 0),
  planned_quantity numeric(14,2) not null check (planned_quantity > 0),
  eta date,
  status text not null default 'Planned'
    check (status in ('Planned','Ordered','In Production','Shipped','At Port','Received','Cancelled')),
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint supply_shipments_company_number_unique unique (company_id, shipment_no)
);

create table public.delivery_orders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  delivery_no text not null,
  customer_name text not null check (length(btrim(customer_name)) > 0),
  required_quantity numeric(14,2) not null check (required_quantity > 0),
  allocated_quantity numeric(14,2) not null default 0
    check (allocated_quantity >= 0 and allocated_quantity <= required_quantity),
  delivery_status text not null default 'Stock Check'
    check (delivery_status in ('Stock Check','Reserved','Ready for Delivery','Dispatched','Delivered','Backorder','Cancelled')),
  promised_delivery_date date,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_orders_company_number_unique unique (company_id, delivery_no)
);

create index supply_shipments_company_eta_idx
  on public.supply_shipments (company_id, eta);
create index supply_shipments_company_status_idx
  on public.supply_shipments (company_id, status);
create index delivery_orders_company_status_date_idx
  on public.delivery_orders (company_id, delivery_status, promised_delivery_date);

create or replace function private.touch_supply_logistics_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;

revoke all on function private.touch_supply_logistics_updated_at() from public, anon, authenticated;

create trigger supply_shipments_touch_updated_at
before update on public.supply_shipments
for each row execute function private.touch_supply_logistics_updated_at();

create trigger delivery_orders_touch_updated_at
before update on public.delivery_orders
for each row execute function private.touch_supply_logistics_updated_at();

alter table public.supply_shipments enable row level security;
alter table public.delivery_orders enable row level security;

revoke all on table public.supply_shipments from anon, authenticated;
revoke all on table public.delivery_orders from anon, authenticated;

grant select, insert on table public.supply_shipments to authenticated;
grant update (eta, status, notes) on table public.supply_shipments to authenticated;
grant select, insert on table public.delivery_orders to authenticated;
grant update (required_quantity, allocated_quantity, delivery_status, promised_delivery_date, notes)
  on table public.delivery_orders to authenticated;

create policy supply_shipments_select_company_member
on public.supply_shipments
for select to authenticated
using ((select private.has_company_membership(company_id)));

create policy supply_shipments_insert_authorized_operator
on public.supply_shipments
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.company_memberships m
    join public.companies c on c.id = m.company_id
    where m.company_id = supply_shipments.company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and c.is_active = true
      and m.role = any (array['owner','admin','manager','inventory','accountant']::text[])
  )
);

create policy supply_shipments_update_authorized_operator
on public.supply_shipments
for update to authenticated
using (
  exists (
    select 1 from public.company_memberships m
    where m.company_id = supply_shipments.company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any (array['owner','admin','manager','inventory']::text[])
  )
)
with check (
  exists (
    select 1 from public.company_memberships m
    where m.company_id = supply_shipments.company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any (array['owner','admin','manager','inventory']::text[])
  )
);

create policy delivery_orders_select_company_member
on public.delivery_orders
for select to authenticated
using ((select private.has_company_membership(company_id)));

create policy delivery_orders_insert_authorized_operator
on public.delivery_orders
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.company_memberships m
    join public.companies c on c.id = m.company_id
    where m.company_id = delivery_orders.company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and c.is_active = true
      and m.role = any (array['owner','admin','manager','inventory','sales','staff']::text[])
  )
);

create policy delivery_orders_update_authorized_operator
on public.delivery_orders
for update to authenticated
using (
  exists (
    select 1 from public.company_memberships m
    where m.company_id = delivery_orders.company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any (array['owner','admin','manager','inventory']::text[])
  )
)
with check (
  exists (
    select 1 from public.company_memberships m
    where m.company_id = delivery_orders.company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any (array['owner','admin','manager','inventory']::text[])
  )
);

comment on table public.supply_shipments is
  'Company-scoped inbound factory/supplier shipment plans from the BOKAN ERP V6.7 Supply & Logistics Control Tower.';
comment on table public.delivery_orders is
  'Company-scoped customer delivery controls from the BOKAN ERP V6.7 Supply & Logistics Control Tower.';
