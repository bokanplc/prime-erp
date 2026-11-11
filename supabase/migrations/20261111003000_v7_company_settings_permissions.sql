-- Allow owners and admins to maintain active-company display and VAT settings.
grant update on public.companies to authenticated;

drop policy if exists companies_owner_admin_update on public.companies;
create policy companies_owner_admin_update on public.companies
  for update to authenticated
  using (
    private.has_company_role(id, array['owner','admin']::public.company_role[])
  )
  with check (
    private.has_company_role(id, array['owner','admin']::public.company_role[])
  );
