-- Scope the retained V6.7 legacy HR screens to the active BlackRock company.
-- These four legacy tables were empty at migration review time. Do not silently
-- assign any pre-existing unscoped HR records to a company.
do $$
declare
  v_table text;
  v_null_rows bigint;
begin
  foreach v_table in array array['employees','leave_requests','performance_reviews','disciplinary_actions'] loop
    execute format('select count(*) from public.%I where company_id is null',v_table) into v_null_rows;
    if v_null_rows > 0 then
      raise exception 'Refusing to scope %. There are % rows without company_id; review and map them before applying this migration.',v_table,v_null_rows;
    end if;

    execute format('alter table public.%I alter column company_id set default private.current_company_id()',v_table);
    execute format('alter table public.%I alter column company_id set not null',v_table);
    execute format(
      'alter table public.%I add constraint %I foreign key (company_id) references public.companies(id) on delete cascade',
      v_table,v_table||'_company_id_fkey'
    );
    execute format('alter table public.%I enable row level security',v_table);
    execute format('create index if not exists %I on public.%I(company_id)',v_table||'_company_id_idx',v_table);

    execute format(
      'create policy %I on public.%I for select to authenticated using (private.has_company_role(company_id,array[''owner'',''admin'',''manager'',''hr'']::text[]))',
      v_table||'_select_hr',v_table
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (private.has_company_role(company_id,array[''owner'',''admin'',''manager'',''hr'']::text[]) and created_by=(select auth.uid()))',
      v_table||'_insert_hr',v_table
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (private.has_company_role(company_id,array[''owner'',''admin'',''manager'',''hr'']::text[])) with check (private.has_company_role(company_id,array[''owner'',''admin'',''manager'',''hr'']::text[]))',
      v_table||'_update_hr',v_table
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (private.has_company_role(company_id,array[''owner'',''admin'',''manager'']::text[]))',
      v_table||'_delete_manager',v_table
    );
  end loop;
end
$$;

revoke all on public.employees,public.leave_requests,public.performance_reviews,public.disciplinary_actions from anon;
grant select,insert,update,delete on public.employees,public.leave_requests,public.performance_reviews,public.disciplinary_actions to authenticated;
