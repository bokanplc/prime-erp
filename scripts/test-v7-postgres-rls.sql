-- Test-only synthetic rows in disposable PostgreSQL; never production data.
insert into auth.users (id) values
  ('10000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000002');

insert into public.companies (id, legal_name, display_name)
values
  ('20000000-0000-4000-8000-000000000001', 'Tenant One Ltd', 'Tenant One'),
  ('20000000-0000-4000-8000-000000000002', 'Tenant Two Ltd', 'Tenant Two');

insert into public.company_memberships (company_id, user_id, role)
values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'sales'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'sales');

insert into public.customers (company_id, legal_name, display_name)
values
  ('20000000-0000-4000-8000-000000000001', 'Customer One', 'Customer One'),
  ('20000000-0000-4000-8000-000000000002', 'Customer Two', 'Customer Two');

insert into storage.objects (bucket_id, name, owner_id)
values
  ('bokan-erp-documents', '20000000-0000-4000-8000-000000000001/tenant-one.pdf', '10000000-0000-4000-8000-000000000001'),
  ('bokan-erp-documents', '20000000-0000-4000-8000-000000000002/tenant-two.pdf', '10000000-0000-4000-8000-000000000002');

do $$
declare
  public_tables_without_rls integer;
begin
  select count(*) into public_tables_without_rls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and not c.relrowsecurity;

  if public_tables_without_rls <> 0 then
    raise exception 'RLS is disabled on % public tables', public_tables_without_rls;
  end if;

  if not exists (select 1 from storage.buckets where id = 'bokan-erp-documents' and public = false) then
    raise exception 'Private company document bucket is missing or public';
  end if;

  if not (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass) then
    raise exception 'Storage object RLS is disabled';
  end if;

  if to_regclass('public.stock_entries') is not null
     or to_regclass('public.stock_ledger') is not null
     or to_regclass('public.supplier_payments') is not null
     or to_regclass('public.customer_receipts') is not null
     or to_regclass('public.journal_entries') is not null
     or to_regclass('public.general_ledger') is not null then
    raise exception 'A deferred legacy stock, payment, or accounting table exists in V7';
  end if;
end
$$;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);

do $$
declare
  visible_customers integer;
  visible_companies integer;
  visible_files integer;
begin
  select count(*) into visible_customers from public.customers;
  select count(*) into visible_companies from public.companies;
  select count(*) into visible_files from storage.objects where bucket_id = 'bokan-erp-documents';

  if visible_customers <> 1 then
    raise exception 'Tenant isolation failed: user can see % customer rows', visible_customers;
  end if;
  if visible_companies <> 1 then
    raise exception 'Tenant isolation failed: user can see % company rows', visible_companies;
  end if;
  if visible_files <> 1 then
    raise exception 'Storage tenant isolation failed: user can see % files', visible_files;
  end if;

  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values ('bokan-erp-documents', '20000000-0000-4000-8000-000000000002/unauthorized.pdf', '10000000-0000-4000-8000-000000000001');
    raise exception 'Cross-company storage upload unexpectedly succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    insert into public.customers (company_id, legal_name, display_name)
    values ('20000000-0000-4000-8000-000000000002', 'Unauthorized Customer', 'Unauthorized');
    raise exception 'Cross-company insert unexpectedly succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;
rollback;

select 'V7 migration smoke test passed: schema, RLS, tenant isolation and excluded modules verified.' as result;
