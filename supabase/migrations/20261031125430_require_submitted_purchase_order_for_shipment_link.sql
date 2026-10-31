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
    if v_type <> 'purchase_order'
       or v_status not in ('submitted','approved','partially_received','received','partially_paid','paid') then
      raise exception 'Shipment can only link to a submitted or active purchase order' using errcode='23514';
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function public.validate_supply_document_links() from public,anon,authenticated;
