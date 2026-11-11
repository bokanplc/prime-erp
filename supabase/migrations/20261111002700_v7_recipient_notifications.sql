-- Recipient-scoped in-app notifications for commercial approvals and request conversion.
begin;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  notification_type text not null check (notification_type in (
    'sales_document_approved',
    'purchase_order_approved',
    'purchase_request_approved',
    'purchase_request_converted'
  )),
  title varchar(180) not null,
  body text not null,
  href text not null,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, company_id)
);

create index idx_notifications_recipient_unread
  on public.notifications (recipient_user_id, company_id, created_at desc)
  where read_at is null;

create index idx_notifications_recipient_recent
  on public.notifications (recipient_user_id, company_id, created_at desc);

alter table public.notifications enable row level security;
alter table public.notifications force row level security;

create policy notifications_recipient_read on public.notifications
  for select to authenticated
  using (
    recipient_user_id = (select auth.uid())
    and private.is_company_member(company_id)
  );

create policy notifications_recipient_mark_read on public.notifications
  for update to authenticated
  using (
    recipient_user_id = (select auth.uid())
    and private.is_company_member(company_id)
  )
  with check (
    recipient_user_id = (select auth.uid())
    and private.is_company_member(company_id)
  );

grant select, update on public.notifications to authenticated;
revoke insert, delete on public.notifications from anon, authenticated;

create or replace function private.prevent_notification_content_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.company_id is distinct from old.company_id
    or new.recipient_user_id is distinct from old.recipient_user_id
    or new.actor_user_id is distinct from old.actor_user_id
    or new.notification_type is distinct from old.notification_type
    or new.title is distinct from old.title
    or new.body is distinct from old.body
    or new.href is distinct from old.href
    or new.metadata is distinct from old.metadata
    or new.created_at is distinct from old.created_at
  then
    raise exception 'Notification content is immutable.'
      using errcode = '42501';
  end if;

  if old.read_at is not null or new.read_at is null then
    raise exception 'Notifications may only be marked read once.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger prevent_notification_content_mutation
before update on public.notifications
for each row execute function private.prevent_notification_content_mutation();

create or replace function private.notify_commercial_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient uuid;
  notification_kind text;
  notification_title text;
  notification_body text;
  destination text;
  reference_number text;
begin
  if tg_op <> 'UPDATE' or new.status is not distinct from old.status then
    return new;
  end if;

  if tg_table_name = 'sales_documents' and new.status = 'approved' then
    recipient := nullif(to_jsonb(new)->>'created_by','')::uuid;
    notification_kind := 'sales_document_approved';
    notification_title := 'Sales document approved';
    reference_number := coalesce(to_jsonb(new)->>'document_number','');
    notification_body := 'Your sales document ' || reference_number || ' has been approved.';
    destination := '/sales/' || (to_jsonb(new)->>'id');
  elsif tg_table_name = 'purchase_orders' and new.status = 'approved' then
    recipient := nullif(to_jsonb(new)->>'created_by','')::uuid;
    notification_kind := 'purchase_order_approved';
    notification_title := 'Purchase order approved';
    reference_number := coalesce(to_jsonb(new)->>'order_number','');
    notification_body := 'Your purchase order ' || reference_number || ' has been approved.';
    destination := '/purchasing/' || (to_jsonb(new)->>'id');
  elsif tg_table_name = 'purchase_requests' and new.status = 'approved' then
    recipient := nullif(to_jsonb(new)->>'requested_by','')::uuid;
    notification_kind := 'purchase_request_approved';
    notification_title := 'Purchase request approved';
    reference_number := coalesce(to_jsonb(new)->>'request_number','');
    notification_body := 'Your purchase request ' || reference_number || ' has been approved.';
    destination := '/purchasing';
  elsif tg_table_name = 'purchase_requests' and new.status = 'converted' then
    recipient := nullif(to_jsonb(new)->>'requested_by','')::uuid;
    notification_kind := 'purchase_request_converted';
    reference_number := coalesce(to_jsonb(new)->>'request_number','');
    notification_title := 'Purchase request converted';
    notification_body := 'Purchase request ' || reference_number || ' has been converted to a supplier order.';
    destination := '/purchasing';
  else
    return new;
  end if;

  if recipient is null or recipient = (select auth.uid()) then
    return new;
  end if;

  insert into public.notifications (
    company_id, recipient_user_id, actor_user_id, notification_type,
    title, body, href, metadata
  ) values (
    new.company_id, recipient, (select auth.uid()), notification_kind,
    notification_title, notification_body, destination,
    jsonb_build_object('entity_table',tg_table_name,'entity_id',to_jsonb(new)->>'id','reference',reference_number)
  );

  return new;
end;
$$;

drop trigger if exists notify_sales_document_status on public.sales_documents;
create trigger notify_sales_document_status
after update of status on public.sales_documents
for each row execute function private.notify_commercial_status_change();

drop trigger if exists notify_purchase_order_status on public.purchase_orders;
create trigger notify_purchase_order_status
after update of status on public.purchase_orders
for each row execute function private.notify_commercial_status_change();

drop trigger if exists notify_purchase_request_status on public.purchase_requests;
create trigger notify_purchase_request_status
after update of status on public.purchase_requests
for each row execute function private.notify_commercial_status_change();

revoke all on function private.prevent_notification_content_mutation() from public, anon, authenticated;
revoke all on function private.notify_commercial_status_change() from public, anon, authenticated;

commit;
