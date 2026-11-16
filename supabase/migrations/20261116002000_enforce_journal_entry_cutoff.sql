drop policy if exists journal_entries_insert on public.journal_entries;
create policy journal_entries_insert on public.journal_entries
for insert to authenticated
with check (
  private.journal_user_role() in ('admin','data_entry')
  and created_by = (select auth.uid())
  and business_day = (now() at time zone 'Africa/Addis_Ababa')::date
  and (now() at time zone 'Africa/Addis_Ababa')::time < time '18:00'
);