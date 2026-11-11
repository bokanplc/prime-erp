-- Consolidate manager deletion and creator rollback into one permissive policy per table.
begin;

drop policy if exists sales_documents_creator_cleanup on public.sales_documents;
drop policy if exists sales_documents_manager_delete on public.sales_documents;
create policy sales_documents_safe_delete on public.sales_documents
  for delete to authenticated
  using (
    private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[])
    or (
      created_by = (select auth.uid())
      and status = 'submitted'
      and not exists (
        select 1 from public.sales_document_lines l
        where l.sales_document_id = sales_documents.id
          and l.company_id = sales_documents.company_id
      )
      and not exists (
        select 1 from public.direct_costs c
        where c.sales_document_id = sales_documents.id
          and c.company_id = sales_documents.company_id
      )
    )
  );

drop policy if exists purchase_orders_creator_cleanup on public.purchase_orders;
drop policy if exists purchase_orders_manager_delete on public.purchase_orders;
create policy purchase_orders_safe_delete on public.purchase_orders
  for delete to authenticated
  using (
    private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[])
    or (
      created_by = (select auth.uid())
      and status = 'submitted'
      and not exists (
        select 1 from public.purchase_order_lines l
        where l.purchase_order_id = purchase_orders.id
          and l.company_id = purchase_orders.company_id
      )
      and not exists (
        select 1 from public.direct_costs c
        where c.purchase_order_id = purchase_orders.id
          and c.company_id = purchase_orders.company_id
      )
    )
  );

drop policy if exists purchase_requests_creator_cleanup on public.purchase_requests;
drop policy if exists purchase_requests_manager_delete on public.purchase_requests;
create policy purchase_requests_safe_delete on public.purchase_requests
  for delete to authenticated
  using (
    private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[])
    or (
      requested_by = (select auth.uid())
      and status = 'submitted'
      and not exists (
        select 1 from public.purchase_request_lines l
        where l.purchase_request_id = purchase_requests.id
          and l.company_id = purchase_requests.company_id
      )
    )
  );

drop policy if exists products_creator_cleanup on public.products;
drop policy if exists products_manager_delete on public.products;
create policy products_safe_delete on public.products
  for delete to authenticated
  using (
    private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[])
    or (
      created_by = (select auth.uid())
      and not exists (select 1 from public.product_prices p where p.product_id = products.id and p.company_id = products.company_id)
      and not exists (select 1 from public.sales_document_lines l where l.product_id = products.id and l.company_id = products.company_id)
      and not exists (select 1 from public.purchase_order_lines l where l.product_id = products.id and l.company_id = products.company_id)
      and not exists (select 1 from public.purchase_request_lines l where l.product_id = products.id and l.company_id = products.company_id)
    )
  );

commit;
