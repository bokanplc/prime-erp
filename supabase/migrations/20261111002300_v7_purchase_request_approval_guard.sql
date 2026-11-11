-- Purchase requests require manager approval at the database boundary.
begin;

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

drop trigger if exists enforce_purchase_request_approval on public.purchase_requests;
create trigger enforce_purchase_request_approval
before insert or update on public.purchase_requests
for each row execute function private.enforce_purchase_request_approval();

revoke all on function private.enforce_purchase_request_approval() from public, anon, authenticated;

commit;
