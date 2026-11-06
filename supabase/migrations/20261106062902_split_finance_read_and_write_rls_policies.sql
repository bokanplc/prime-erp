-- Split finance write permissions from read permissions so SELECT has one
-- permissive policy per table. The original ALL policies are replaced with
-- INSERT/UPDATE/DELETE policies preserving their exact membership predicates.
drop policy if exists fiscal_periods_manage_finance on public.fiscal_periods;
create policy fiscal_periods_insert_finance
  on public.fiscal_periods for insert to authenticated
  with check (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = fiscal_periods.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
    and created_by = (select auth.uid())
  );
create policy fiscal_periods_update_finance
  on public.fiscal_periods for update to authenticated
  using (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = fiscal_periods.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
  )
  with check (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = fiscal_periods.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
    and created_by = (select auth.uid())
  );
create policy fiscal_periods_delete_finance
  on public.fiscal_periods for delete to authenticated
  using (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = fiscal_periods.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
  );

drop policy if exists ledger_accounts_manage_finance on public.ledger_accounts;
create policy ledger_accounts_insert_finance
  on public.ledger_accounts for insert to authenticated
  with check (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = ledger_accounts.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
    and created_by = (select auth.uid())
  );
create policy ledger_accounts_update_finance
  on public.ledger_accounts for update to authenticated
  using (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = ledger_accounts.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
  )
  with check (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = ledger_accounts.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
    and created_by = (select auth.uid())
  );
create policy ledger_accounts_delete_finance
  on public.ledger_accounts for delete to authenticated
  using (
    exists (
      select 1 from public.company_memberships m
      where m.company_id = ledger_accounts.company_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role = any (array['owner','admin','manager','accountant'])
    )
  );
