alter table public.supply_shipments
  add column purchase_document_id uuid null;
alter table public.delivery_orders
  add column sales_document_id uuid null;

alter table public.supply_shipments
  add constraint supply_shipments_purchase_document_same_company_fk
  foreign key (company_id,purchase_document_id)
  references public.purchase_documents(company_id,id)
  on delete restrict;

alter table public.delivery_orders
  add constraint delivery_orders_sales_document_same_company_fk
  foreign key (company_id,sales_document_id)
  references public.sales_documents(company_id,id)
  on delete restrict;

create index supply_shipments_company_purchase_document_idx
  on public.supply_shipments(company_id,purchase_document_id)
  where purchase_document_id is not null;
create index delivery_orders_company_sales_document_idx
  on public.delivery_orders(company_id,sales_document_id)
  where sales_document_id is not null;

create or replace function public.validate_supply_document_links()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_type text;
  v_status text;
begin
  if new.purchase_document_id is not null then
    select p.document_type,p.status
      into v_type,v_status
      from public.purchase_documents p
     where p.company_id=new.company_id and p.id=new.purchase_document_id
     for key share;
    if not found then
      raise exception 'Purchase document must belong to the selected company' using errcode='23503';
    end if;
    if v_type <> 'purchase_order' or v_status in ('cancelled','void') then
      raise exception 'Shipment can only link to a non-cancelled purchase order' using errcode='23514';
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.validate_delivery_sales_document_link()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_type text;
  v_status text;
  v_customer_name text;
begin
  if new.sales_document_id is not null then
    select d.document_type,d.status,c.name
      into v_type,v_status,v_customer_name
      from public.sales_documents d
      left join public.customers c
        on c.company_id=d.company_id and c.id=d.customer_id
     where d.company_id=new.company_id and d.id=new.sales_document_id
     for key share of d;
    if not found then
      raise exception 'Sales document must belong to the selected company' using errcode='23503';
    end if;
    if v_type not in ('sales_order','invoice') or v_status not in ('approved','posted','partially_paid','paid') then
      raise exception 'Delivery can only link to an approved or posted sales order or invoice' using errcode='23514';
    end if;
    if v_customer_name is not null then
      new.customer_name := v_customer_name;
    end if;
  end if;
  return new;
end;
$function$;

create trigger supply_shipments_validate_purchase_document
before insert or update of company_id,purchase_document_id
on public.supply_shipments
for each row execute function public.validate_supply_document_links();

create trigger delivery_orders_validate_sales_document
before insert or update of company_id,sales_document_id
on public.delivery_orders
for each row execute function public.validate_delivery_sales_document_link();

revoke all on function public.validate_supply_document_links() from public,anon,authenticated;
revoke all on function public.validate_delivery_sales_document_link() from public,anon,authenticated;
