alter table public.purchase_documents
  drop constraint if exists purchase_documents_status_check;
alter table public.purchase_documents
  add constraint purchase_documents_status_check
  check (status = any (array['draft','submitted','approved','partially_received','received','partially_paid','paid','cancelled','void']));

create or replace function public.receive_purchase_document(p_purchase_document_id uuid, p_items jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_doc public.purchase_documents%rowtype;
  v_item record;
  v_updated integer := 0;
  v_movement_count integer := 0;
  v_all_received boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;
  if p_purchase_document_id is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Purchase document ID and at least one received item are required';
  end if;

  select * into v_doc
  from public.purchase_documents
  where id = p_purchase_document_id
  for update;

  if not found then raise exception 'Purchase document not found'; end if;
  if not private.has_company_membership(v_doc.company_id) then
    raise exception 'Active company membership required';
  end if;
  if v_doc.document_type = 'purchase_return' then
    raise exception 'Purchase returns cannot be received as incoming stock';
  end if;
  if v_doc.status not in ('approved','partially_received') then
    raise exception 'Only approved purchase documents can be received';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as x(item_id uuid, quantity_received numeric)
    where x.item_id is null or x.quantity_received is null or x.quantity_received <= 0
  ) then raise exception 'Each received item needs a valid item ID and positive quantity'; end if;

  if (select count(*) from jsonb_to_recordset(p_items) as x(item_id uuid, quantity_received numeric))
     <> (select count(distinct item_id) from jsonb_to_recordset(p_items) as x(item_id uuid, quantity_received numeric)) then
    raise exception 'Duplicate item IDs are not allowed in one receipt';
  end if;

  for v_item in
    select x.item_id, x.quantity_received, pi.product_id, pi.quantity, pi.received_quantity,
           pi.unit_cost, pi.description, pi.company_id
    from jsonb_to_recordset(p_items) as x(item_id uuid, quantity_received numeric)
    join public.purchase_document_items pi
      on pi.id = x.item_id and pi.purchase_document_id = p_purchase_document_id
    order by pi.id
    for update of pi
  loop
    if v_item.company_id <> v_doc.company_id then raise exception 'Company mismatch'; end if;
    if v_item.product_id is null then raise exception 'Every received stock item must be linked to a product'; end if;
    if v_item.received_quantity + v_item.quantity_received > v_item.quantity then
      raise exception 'Received quantity exceeds ordered quantity for item %', v_item.description;
    end if;

    update public.purchase_document_items
      set received_quantity = received_quantity + v_item.quantity_received
      where id = v_item.item_id
        and purchase_document_id = p_purchase_document_id;

    insert into public.stock_movements
      (company_id, product_id, movement_type, quantity, unit_cost, reference_type, reference_id, notes, created_by)
    values
      (v_doc.company_id, v_item.product_id, 'purchase_receipt', v_item.quantity_received,
       v_item.unit_cost, 'purchase_document', p_purchase_document_id,
       'Receipt for ' || v_doc.document_number || ': ' || v_item.description, (select auth.uid()));
    v_updated := v_updated + 1;
    v_movement_count := v_movement_count + 1;
  end loop;

  if v_updated <> jsonb_array_length(p_items) then
    raise exception 'One or more received items do not belong to this purchase document';
  end if;

  select bool_and(received_quantity >= quantity) into v_all_received
  from public.purchase_document_items
  where purchase_document_id = p_purchase_document_id;

  update public.purchase_documents
  set status = case when v_all_received then 'received' else 'partially_received' end,
      updated_at = now()
  where id = p_purchase_document_id;

  return jsonb_build_object('purchase_document_id', p_purchase_document_id,
    'items_received', v_updated, 'stock_movements_created', v_movement_count,
    'status', case when v_all_received then 'received' else 'partially_received' end);
end;
$$;

revoke all on function public.receive_purchase_document(uuid, jsonb) from public, anon;
grant execute on function public.receive_purchase_document(uuid, jsonb) to authenticated;
