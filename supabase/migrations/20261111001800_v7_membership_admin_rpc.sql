-- Expose narrowly-scoped membership RPCs through PostgREST and tighten admin removal.
begin;

drop policy if exists memberships_owner_admin_delete on public.company_memberships;
create policy memberships_owner_admin_delete on public.company_memberships
  for delete to authenticated
  using (
    user_id <> (select auth.uid())
    and (
      private.has_company_role(company_id, array['owner']::public.company_role[])
      or (
        role not in ('owner','admin')
        and private.has_company_role(company_id, array['admin']::public.company_role[])
      )
    )
  );

create or replace function public.list_company_members(target_company_id uuid)
returns table (
  user_id uuid,
  email text,
  role public.company_role,
  is_active boolean,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.list_company_members(target_company_id);
$$;

create or replace function public.find_company_auth_user(target_company_id uuid, target_email text)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select private.find_company_auth_user(target_company_id, target_email);
$$;

revoke all on function public.list_company_members(uuid) from public, anon;
revoke all on function public.find_company_auth_user(uuid, text) from public, anon;
grant execute on function public.list_company_members(uuid) to authenticated;
grant execute on function public.find_company_auth_user(uuid, text) to authenticated;

commit;
