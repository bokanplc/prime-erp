-- Candidate migration: persist operational sales orders in the existing sales document model.
-- Additive only. No receivables, collections, payment or general-ledger workflow is created.

begin;

alter table public.sales_documents
  add column if not exists operational_stage text not null default 'customer_order';

alter table public.sales_documents
  drop constraint if exists sales_documents_operational_stage_check,
  add constraint sales_documents_operational_stage_check
    check (operational_stage in (
      'customer_order','confirmed','stock_check','stock_reserved',
      'ready_delivery','dispatched','delivered','customer_confirmation',
      'after_sales','cancelled'
    ));

create index if not exists sales_documents_company_operational_stage_idx
  on public.sales_documents(company_id, operational_stage, document_date desc)
  where document_type = 'sales_order';

-- Preserve the sold product on the linked fulfilment control so stock allocation
-- can later be made against the correct company-owned catalogue item.
alter table public.delivery_orders
  add column if not exists product_id uuid;

alter table public.delivery_orders
  drop constraint if exists delivery_orders_product_same_company_fk,
  add constraint delivery_orders_product_same_company_fk
    foreign key (company_id, product_id)
    references public.products(company_id, id)
    on delete restrict;

create index if not exists delivery_orders_company_product_idx
  on public.delivery_orders(company_id, product_id)
  where product_id is not null;

create or replace function public.create_blackrock_operational_sales_order(
  p_company_id uuid,
  p_customer_id uuid,
  p_product_description text,
  p_quantity numeric,
  p_unit text,
  p_unit_price numeric,
  p_product_id uuid default null,
  p_due_date date default null,
  p_notes text default null
)
returns public.sales_documents
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_document public.sales_documents;
  v_description text := trim(coalesce(p_product_description,''));
  v_unit text := trim(coalesce(p_unit,''));
  v_number text;
  v_delivery_number text;
  v_customer_name text;
  v_total numeric(16,2);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.has_company_membership(p_company_id) then
    raise exception 'Active company membership required';
  end if;
  if not exists (
    select 1 from public.companies c
    where c.id=p_company_id and c.is_active=true
  ) then raise exception 'Selected company is inactive'; end if;
  if not exists (
    select 1 from public.company_memberships m
    where m.company_id=p_company_id and m.user_id=v_user and m.is_active=true
      and m.role in ('owner','admin','manager','sales','staff')
  ) then raise exception 'Role is not permitted to create operational sales orders'; end if;
  select c.name into v_customer_name
  from public.customers c
  where c.id=p_customer_id and c.company_id=p_company_id;
  if v_customer_name is null then raise exception 'Customer does not belong to the selected company'; end if;
  if v_description='' or v_unit='' or p_quantity is null or p_quantity<=0
     or p_unit_price is null or p_unit_price<0 then
    raise exception 'Product, unit, positive quantity and non-negative unit price are required';
  end if;
  if p_product_id is not null and not exists (
    select 1 from public.products p
    where p.id=p_product_id and p.company_id=p_company_id and p.is_active=true
  ) then raise exception 'Selected product is not active in the selected company'; end if;

  v_total := round(p_quantity*p_unit_price,2);
  v_number := 'SO-' || to_char(current_date,'YYYYMMDD') || '-' ||
              upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  insert into public.sales_documents(
    company_id,customer_id,document_type,document_number,status,
    document_date,due_date,currency_code,subtotal,tax_total,discount_total,
    grand_total,notes,created_by,operational_stage
  ) values (
    p_company_id,p_customer_id,'sales_order',v_number,'submitted',
    current_date,p_due_date,'ETB',v_total,0,0,v_total,
    nullif(trim(coalesce(p_notes,'')),''),v_user,'customer_order'
  )
  returning * into v_document;

  insert into public.sales_document_items(
    company_id,document_id,product_id,description,quantity,unit,unit_price,
    tax_rate,line_subtotal,line_tax,line_total
  ) values (
    p_company_id,v_document.id,p_product_id,v_description,p_quantity,v_unit,p_unit_price,
    0,v_total,0,v_total
  );

  -- Create the linked fulfilment control in the same transaction.
  -- This records demand only; it does not reserve or issue stock.
  v_delivery_number := 'DO-' || to_char(current_date,'YYYYMMDD') || '-' ||
                       upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  insert into public.delivery_orders(
    company_id,delivery_no,customer_name,sales_document_id,product_id,
    required_quantity,allocated_quantity,delivery_status,
    promised_delivery_date,notes,created_by
  ) values (
    p_company_id,v_delivery_number,v_customer_name,v_document.id,p_product_id,
    p_quantity,0,'Stock Check',p_due_date,
    nullif(trim(coalesce(p_notes,'')),''),v_user
  );

  return v_document;
end;
$$;

revoke all on function public.create_blackrock_operational_sales_order(uuid,uuid,text,numeric,text,numeric,uuid,date,text)
  from public, anon;
grant execute on function public.create_blackrock_operational_sales_order(uuid,uuid,text,numeric,text,numeric,uuid,date,text)
  to authenticated;


-- Operational stage changes use a narrow RPC rather than granting broad document updates.
create or replace function public.update_blackrock_operational_sales_order_stage(
  p_company_id uuid,
  p_sales_document_id uuid,
  p_stage text
)
returns public.sales_documents
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_document public.sales_documents;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.has_company_membership(p_company_id) then
    raise exception 'Active company membership required';
  end if;
  if not exists (select 1 from public.companies c where c.id=p_company_id and c.is_active=true) then
    raise exception 'Selected company is inactive';
  end if;
  if not exists (
    select 1 from public.company_memberships m
    where m.company_id=p_company_id and m.user_id=v_user and m.is_active=true
      and m.role in ('owner','admin','manager','sales','staff')
  ) then raise exception 'Role is not permitted to update operational sales order stages'; end if;
  if p_stage is null or p_stage not in (
    'customer_order','confirmed','stock_check','stock_reserved',
    'ready_delivery','dispatched','delivered','customer_confirmation',
    'after_sales','cancelled'
  ) then raise exception 'Unsupported operational order stage'; end if;

  update public.sales_documents
  set operational_stage=p_stage,updated_at=now()
  where id=p_sales_document_id and company_id=p_company_id and document_type='sales_order'
  returning * into v_document;

  if not found then raise exception 'Sales order not found in the selected company'; end if;
  return v_document;
end;
$$;

revoke all on function public.update_blackrock_operational_sales_order_stage(uuid,uuid,text)
  from public, anon;
grant execute on function public.update_blackrock_operational_sales_order_stage(uuid,uuid,text)
  to authenticated;

commit;
