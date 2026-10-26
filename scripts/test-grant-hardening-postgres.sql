\set ON_ERROR_STOP on

-- Disposable PostgreSQL only. The preceding Proforma test creates the roles and
-- sample public schema. This deliberately simulates the broad table grants found
-- in the live project before applying the proposed hardening candidate.
grant all privileges on all tables in schema public to authenticated;
create or replace view public.grant_hardening_test_view
with (security_invoker = true) as select id from public.proformas;
grant all privileges on public.grant_hardening_test_view to authenticated;

do $precheck$
begin
  if not has_table_privilege('authenticated','public.proformas','TRUNCATE') then
    raise exception 'Test setup failed: broad TRUNCATE grant was not present';
  end if;
  if not has_table_privilege('authenticated','public.proformas','TRIGGER') then
    raise exception 'Test setup failed: broad TRIGGER grant was not present';
  end if;
  if not has_table_privilege('authenticated','public.proformas','REFERENCES') then
    raise exception 'Test setup failed: broad REFERENCES grant was not present';
  end if;
end
$precheck$;

\i supabase/candidates/revoke_non_dml_authenticated_privileges.sql

do $assert$
declare
  t text;
  tables text[] := array['companies','profiles','company_bank_accounts','custom_terms','proformas','grant_hardening_test_view'];
  privilege text;
begin
  foreach t in array tables loop
    foreach privilege in array array['TRUNCATE','TRIGGER','REFERENCES'] loop
      if has_table_privilege('authenticated','public.'||t,privilege) then
        raise exception 'FAIL: authenticated retains % on public.%',privilege,t;
      end if;
    end loop;
    foreach privilege in array array['SELECT','INSERT','UPDATE','DELETE'] loop
      if not has_table_privilege('authenticated','public.'||t,privilege) then
        raise exception 'FAIL: hardening unexpectedly removed % on public.%',privilege,t;
      end if;
    end loop;
  end loop;
end
$assert$;

drop view public.grant_hardening_test_view;
revoke all privileges on all tables in schema public from authenticated;
