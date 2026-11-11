-- Link a purchase order to the internal request it fulfills and authorize controlled conversion.
begin;

alter table public.purchase_orders
  add column purchase_request_id uuid,
  add constraint purchase_orders_request_same_company_fk
    foreign key (purchase_request_id, company_id)
    references public.purchase_requests(id, company_id);

create index if not exists idx_purchase_orders_request_company
  on public.purchase_orders (purchase_request_id, company_id);

create or replace function private.enforce_purchase_request_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  protected_change boolean := false;
  approval_transition boolean := false;
begin
  if tg_op = 'INSERT' then
    protected_change := new.status = 'approved'
      or new.approved_by is not null
      or new.approved_at is not null;
    approval_transition := new.status = 'approved';
  else
    protected_change :=
      new.status is distinct from old.status
      or new.approved_by is distinct from old.approved_by
      or new.approved_at is distinct from old.approved_at
      or old.status = 'approved';
    approval_transition := new.status = 'approved' and old.status is distinct from 'approved';
  end if;

  if protected_change then
    if tg_op = 'UPDATE' and old.status = 'approved' and new.status = 'converted' then
      if not private.has_company_role(
        new.company_id,
        array['owner','admin','manager','purchasing']::public.company_role[]
      ) then
        raise exception 'Only purchasing or management roles may convert an approved purchase request.'
          using errcode = '42501';
      end if;
      if not exists (
        select 1 from public.purchase_orders po
        where po.company_id = new.company_id
          and po.purchase_request_id = new.id
      ) then
        raise exception 'A linked purchase order must exist before a request can be marked converted.'
          using errcode = '23514';
      end if;
      return new;
    end if;

    if not private.has_company_role(
      new.company_id,
      array['owner','admin','manager']::public.company_role[]
    ) then
      raise exception 'Only an owner, admin or manager may approve or change an approved purchase request.'
        using errcode = '42501';
    end if;
    if new.status = 'approved' and (
      new.approved_by is null
      or new.approved_at is null
    ) then
      raise exception 'Approved purchase requests must retain approval metadata.'
        using errcode = '42501';
    end if;
    if approval_transition and new.approved_by is distinct from (select auth.uid()) then
      raise exception 'The approving user must be the acting authorized user.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

commit;
