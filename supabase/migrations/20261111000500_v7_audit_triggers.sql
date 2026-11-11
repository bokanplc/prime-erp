-- Capture append-only audit metadata for critical business table changes.
begin;

create or replace function private.capture_audit_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data jsonb;
  event_company_id uuid;
  event_entity_id text;
begin
  if tg_op = 'DELETE' then
    row_data := to_jsonb(old);
  else
    row_data := to_jsonb(new);
  end if;

  event_company_id := (row_data ->> 'company_id')::uuid;
  event_entity_id := row_data ->> 'id';

  if event_company_id is not null then
    insert into public.audit_events (
      company_id, actor_user_id, action, entity_table, entity_id, metadata
    ) values (
      event_company_id,
      (select auth.uid()),
      lower(tg_table_name) || '.' || lower(tg_op),
      tg_table_name,
      event_entity_id,
      jsonb_build_object('operation', tg_op)
    );
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function private.capture_audit_event() from public, anon, authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'customers','suppliers','crm_leads','crm_activities','sales_documents',
    'sales_document_lines','purchase_orders','purchase_order_lines','direct_costs',
    'delivery_jobs','tasks','documents','products','product_prices',
    'purchase_requests','purchase_request_lines'
  ]
  loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I for each row execute function private.capture_audit_event()',
      table_name || '_audit_event',
      table_name
    );
  end loop;
end $$;

commit;
