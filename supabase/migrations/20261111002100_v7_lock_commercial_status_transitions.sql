-- Protect all commercial status transitions and lock approved/issued documents to approvers.
begin;

create or replace function private.enforce_commercial_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  protected_change boolean := false;
  requires_approval_metadata boolean := false;
begin
  if tg_op = 'INSERT' then
    protected_change := new.status in ('approved','sent','accepted')
      or new.approved_by is not null
      or new.approved_at is not null;
  else
    protected_change :=
      new.status is distinct from old.status
      or new.approved_by is distinct from old.approved_by
      or new.approved_at is distinct from old.approved_at
      or old.status in ('approved','sent','accepted');
  end if;

  if protected_change then
    if not private.has_company_role(
      new.company_id,
      array['owner','admin','manager']::public.company_role[]
    ) then
      raise exception 'Only an owner, admin or manager may change commercial approval status or edit an approved document.'
        using errcode = '42501';
    end if;

    requires_approval_metadata := new.status in ('approved','sent','accepted');
    if requires_approval_metadata and (
      new.approved_by is null
      or new.approved_at is null
    ) then
      raise exception 'Approved or issued commercial documents must retain approval metadata.'
        using errcode = '42501';
    end if;

    if new.status = 'approved'
      and new.approved_by is distinct from (select auth.uid()) then
      raise exception 'The approving user must be the acting authorized user.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

commit;
