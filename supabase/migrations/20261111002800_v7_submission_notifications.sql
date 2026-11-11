-- Notify management when new sales, purchasing or internal purchase requests await approval.
begin;

alter table public.notifications drop constraint if exists notifications_notification_type_check;
alter table public.notifications
  add constraint notifications_notification_type_check
  check (notification_type in (
    'sales_document_submitted',
    'sales_document_approved',
    'purchase_order_submitted',
    'purchase_order_approved',
    'purchase_request_submitted',
    'purchase_request_approved',
    'purchase_request_converted'
  ));

create or replace function private.notify_commercial_submission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid;
  notification_kind text;
  notification_title text;
  notification_body text;
  destination text;
  reference_number text;
  manager record;
begin
  if new.status <> 'submitted' then
    return new;
  end if;

  if tg_table_name = 'sales_documents' then
    actor := nullif(to_jsonb(new)->>'created_by','')::uuid;
    notification_kind := 'sales_document_submitted';
    notification_title := 'Sales document awaiting approval';
    reference_number := coalesce(to_jsonb(new)->>'document_number','');
    notification_body := 'Sales document ' || reference_number || ' is awaiting your review.';
    destination := '/sales';
  elsif tg_table_name = 'purchase_orders' then
    actor := nullif(to_jsonb(new)->>'created_by','')::uuid;
    notification_kind := 'purchase_order_submitted';
    notification_title := 'Purchase order awaiting approval';
    reference_number := coalesce(to_jsonb(new)->>'order_number','');
    notification_body := 'Purchase order ' || reference_number || ' is awaiting your review.';
    destination := '/purchasing';
  elsif tg_table_name = 'purchase_requests' then
    actor := nullif(to_jsonb(new)->>'requested_by','')::uuid;
    notification_kind := 'purchase_request_submitted';
    notification_title := 'Purchase request awaiting approval';
    reference_number := coalesce(to_jsonb(new)->>'request_number','');
    notification_body := 'Purchase request ' || reference_number || ' is awaiting your review.';
    destination := '/purchasing';
  else
    return new;
  end if;

  actor := coalesce(actor,(select auth.uid()));

  for manager in
    select m.user_id
    from public.company_memberships m
    where m.company_id = new.company_id
      and m.is_active
      and m.role in ('owner','admin','manager')
      and m.user_id is distinct from actor
  loop
    insert into public.notifications (
      company_id, recipient_user_id, actor_user_id, notification_type,
      title, body, href, metadata
    ) values (
      new.company_id, manager.user_id, actor, notification_kind,
      notification_title, notification_body, destination,
      jsonb_build_object('entity_table',tg_table_name,'entity_id',to_jsonb(new)->>'id','reference',reference_number)
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists notify_sales_document_submission on public.sales_documents;
create trigger notify_sales_document_submission
after insert on public.sales_documents
for each row execute function private.notify_commercial_submission();

drop trigger if exists notify_purchase_order_submission on public.purchase_orders;
create trigger notify_purchase_order_submission
after insert on public.purchase_orders
for each row execute function private.notify_commercial_submission();

drop trigger if exists notify_purchase_request_submission on public.purchase_requests;
create trigger notify_purchase_request_submission
after insert on public.purchase_requests
for each row execute function private.notify_commercial_submission();

revoke all on function private.notify_commercial_submission() from public, anon, authenticated;

commit;
