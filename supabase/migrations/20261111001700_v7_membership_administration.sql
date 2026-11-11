-- Secure company membership administration for existing V7 Auth users.
begin;

drop policy if exists memberships_self_or_manager_read on public.company_memberships;
create policy memberships_self_or_admin_read on public.company_memberships
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[])
  );

drop policy if exists memberships_owner_admin_insert on public.company_memberships;
create policy memberships_owner_admin_insert on public.company_memberships
  for insert to authenticated
  with check (
    user_id <> (select auth.uid())
    and (
      (role in ('manager','sales','purchasing','operations','data_entry','viewer')
        and private.has_company_role(company_id, array['owner','admin']::public.company_role[]))
      or
      (role in ('owner','admin')
        and private.has_company_role(company_id, array['owner']::public.company_role[]))
    )
  );

drop policy if exists memberships_owner_admin_update on public.company_memberships;
create policy memberships_owner_admin_update on public.company_memberships
  for update to authenticated
  using (
    user_id <> (select auth.uid())
    and (
      private.has_company_role(company_id, array['owner']::public.company_role[])
      or (
        role <> 'owner'
        and private.has_company_role(company_id, array['admin']::public.company_role[])
      )
    )
  )
  with check (
    user_id <> (select auth.uid())
    and (
      private.has_company_role(company_id, array['owner']::public.company_role[])
      or (
        role not in ('owner','admin')
        and private.has_company_role(company_id, array['admin']::public.company_role[])
      )
    )
  );

drop policy if exists memberships_owner_admin_delete on public.company_memberships;
create policy memberships_owner_admin_delete on public.company_memberships
  for delete to authenticated
  using (
    user_id <> (select auth.uid())
    and (
      private.has_company_role(company_id, array['owner']::public.company_role[])
      or (
        role <> 'owner'
        and private.has_company_role(company_id, array['admin']::public.company_role[])
      )
    )
  );

grant select, insert, update, delete on public.company_memberships to authenticated;

create or replace function private.list_company_members(target_company_id uuid)
returns table (
  user_id uuid,
  email text,
  role public.company_role,
  is_active boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_company_role(
    target_company_id,
    array['owner','admin','manager']::public.company_role[]
  ) then
    raise exception 'You are not authorized to view company members.'
      using errcode = '42501';
  end if;

  return query
  select m.user_id, u.email::text, m.role, m.is_active, m.created_at
  from public.company_memberships m
  join auth.users u on u.id = m.user_id
  where m.company_id = target_company_id
  order by lower(coalesce(u.email, '')), m.created_at;
end;
$$;

create or replace function private.find_company_auth_user(target_company_id uuid, target_email text)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  found_user_id uuid;
begin
  if not private.has_company_role(
    target_company_id,
    array['owner','admin']::public.company_role[]
  ) then
    raise exception 'Only a company owner or admin may add members.'
      using errcode = '42501';
  end if;

  select u.id into found_user_id
  from auth.users u
  where lower(u.email) = lower(trim(target_email))
  limit 1;

  return found_user_id;
end;
$$;

revoke all on function private.list_company_members(uuid) from public, anon;
revoke all on function private.find_company_auth_user(uuid, text) from public, anon;
grant execute on function private.list_company_members(uuid) to authenticated;
grant execute on function private.find_company_auth_user(uuid, text) to authenticated;

commit;
