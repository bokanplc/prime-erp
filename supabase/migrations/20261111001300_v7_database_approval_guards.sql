-- Enforce approval authority at the database boundary, not only in server actions.
begin;

create or replace function private.enforce_commercial_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  approval_changed boolean;
begin
  approval_changed :=
    new.status = 'approved'
    or new.approved_by is distinct from old.approved_by
    or new.approved_at is distinct from old.approved_at;

  if approval_changed then
    if not private.has_company_role(
      new.company_id,
      array['owner','admin','manager']::public.company_role[]
    ) then
      raise exception 'Only an owner, admin or manager may approve commercial documents.'
        using errcode = '42501';
    end if;

    if new.status = 'approved' and (
      new.approved_by is distinct from (select auth.uid())
      or new.approved_at is null
    ) then
      raise exception 'Approval must be recorded by the acting authorized user.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_sales_document_approval on public.sales_documents;
create trigger enforce_sales_document_approval
before insert or update on public.sales_documents
for each row execute function private.enforce_commercial_approval();

drop trigger if exists enforce_purchase_order_approval on public.purchase_orders;
create trigger enforce_purchase_order_approval
before insert or update on public.purchase_orders
for each row execute function private.enforce_commercial_approval();

revoke all on function private.enforce_commercial_approval() from public, anon, authenticated;

commit;
