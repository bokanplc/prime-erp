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

create or replace function public.create_blackrock_operational_sales_order(
  p_company_id uuid,
  p_customer_id uuid,
  p_product_description text,
  p_quantity numeric,
  p_unit text,
  p_unit_price numeric,
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
  if not exists (
    select 1 from public.customers c
    where c.id=p_customer_id and c.company_id=p_company_id
  ) then raise exception 'Customer does not belong to the selected company'; end if;
  if v_description='' or v_unit='' or p_quantity is null or p_quantity<=0
     or p_unit_price is null or p_unit_price<0 then
    raise exception 'Product, unit, positive quantity and non-negative unit price are required';
  end if;

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
    company_id,document_id,description,quantity,unit,unit_price,
    tax_rate,line_subtotal,line_tax,line_total
  ) values (
    p_company_id,v_document.id,v_description,p_quantity,v_unit,p_unit_price,
    0,v_total,0,v_total
  );

  return v_document;
end;
$$;

revoke all on function public.create_blackrock_operational_sales_order(uuid,uuid,text,numeric,text,numeric,date,text)
  from public, anon;
grant execute on function public.create_blackrock_operational_sales_order(uuid,uuid,text,numeric,text,numeric,date,text)
  to authenticated;

commit;
