-- Test-only synthetic rows in disposable PostgreSQL; never production data.
insert into auth.users (id) values
  ('10000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000002'),
  ('10000000-0000-4000-8000-000000000003'),
  ('10000000-0000-4000-8000-000000000004');

insert into public.companies (id, legal_name, display_name)
values
  ('20000000-0000-4000-8000-000000000001', 'Tenant One Ltd', 'Tenant One'),
  ('20000000-0000-4000-8000-000000000002', 'Tenant Two Ltd', 'Tenant Two');

insert into public.company_memberships (company_id, user_id, role)
values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'sales'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'sales'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'data_entry'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', 'manager');

insert into public.customers (company_id, legal_name, display_name)
values
  ('20000000-0000-4000-8000-000000000001', 'Customer One', 'Customer One'),
  ('20000000-0000-4000-8000-000000000002', 'Customer Two', 'Customer Two');

insert into storage.objects (bucket_id, name, owner_id)
values
  ('bokan-erp-documents', '20000000-0000-4000-8000-000000000001/tenant-one.pdf', '10000000-0000-4000-8000-000000000001'),
  ('bokan-erp-documents', '20000000-0000-4000-8000-000000000002/tenant-two.pdf', '10000000-0000-4000-8000-000000000002');

insert into public.suppliers (id, company_id, legal_name)
values ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Supplier One');

insert into public.products (id, company_id, name, unit_of_measure)
values ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Test Product','pcs');

insert into public.purchase_orders (id, company_id, order_number, supplier_id, status)
values ('50000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PO-TEST-APPROVAL','30000000-0000-4000-8000-000000000001','submitted');

insert into public.sales_documents (id, company_id, document_number, customer_id, document_type, status)
select '60000000-0000-4000-8000-000000000001', company_id, 'PRO-TEST-APPROVAL', id, 'proforma', 'submitted'
from public.customers
where company_id = '20000000-0000-4000-8000-000000000001' and legal_name = 'Customer One';


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


begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);

insert into public.suppliers (company_id, legal_name)
values ('20000000-0000-4000-8000-000000000001', 'Data Entry Supplier');

insert into public.products (company_id, name, unit_of_measure)
values ('20000000-0000-4000-8000-000000000001', 'Data Entry Product', 'pcs');

insert into public.product_prices (company_id, product_id, price_type, unit_price)
values ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'purchase', 125);

insert into public.purchase_orders (company_id, order_number, supplier_id, status)
values ('20000000-0000-4000-8000-000000000001', 'PO-DATA-ENTRY', '30000000-0000-4000-8000-000000000001', 'submitted');

do $data_entry_test$
begin
  begin
    update public.purchase_orders
    set status = 'approved', approved_by = '10000000-0000-4000-8000-000000000003', approved_at = now()
    where id = '50000000-0000-4000-8000-000000000001';
    raise exception 'Data-entry user unexpectedly approved a purchase order';
  exception
    when insufficient_privilege then null;
  end;

  begin
    update public.sales_documents
    set status = 'approved', approved_by = '10000000-0000-4000-8000-000000000003', approved_at = now()
    where id = '60000000-0000-4000-8000-000000000001';
    raise exception 'Data-entry user unexpectedly approved a sales document';
  exception
    when insufficient_privilege then null;
  end;
end
$data_entry_test$;
rollback;


begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);

update public.purchase_orders
set status = 'approved', approved_by = '10000000-0000-4000-8000-000000000004', approved_at = now()
where id = '50000000-0000-4000-8000-000000000001';

update public.sales_documents
set status = 'approved', approved_by = '10000000-0000-4000-8000-000000000004', approved_at = now()
where id = '60000000-0000-4000-8000-000000000001';

rollback;

select 'V7 migration smoke test passed: schema, tenant isolation, private storage, data-entry permissions, manager approvals and excluded modules verified.' as result;
