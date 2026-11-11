-- Audit history is restricted to management roles at the database boundary.
drop policy if exists audit_events_member_read on public.audit_events;
create policy audit_events_management_read on public.audit_events
  for select to authenticated
  using (
    private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[])
  );
