-- Allow company admins to assign/manage other admins while keeping owner reserved.
begin;

drop policy if exists memberships_owner_admin_insert on public.company_memberships;
create policy memberships_owner_admin_insert on public.company_memberships
  for insert to authenticated
  with check (
    user_id <> (select auth.uid())
    and (
      (role in ('manager','sales','purchasing','operations','data_entry','viewer','admin')
        and private.has_company_role(company_id, array['owner','admin']::public.company_role[]))
      or
      (role = 'owner'
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
        role <> 'owner'
        and private.has_company_role(company_id, array['admin']::public.company_role[])
      )
    )
  );

commit;
