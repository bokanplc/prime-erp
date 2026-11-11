-- Allow safe rollback of a newly-created parent when its first line/price insert fails.
-- Existing documents and referenced products remain manager-deletion only.
begin;

drop policy if exists sales_documents_creator_cleanup on public.sales_documents;
create policy sales_documents_creator_cleanup on public.sales_documents
  for delete to authenticated
  using (
    created_by = (select auth.uid())
    and status = 'submitted'
    and not exists (
      select 1 from public.sales_document_lines l
      where l.sales_document_id = sales_documents.id
        and l.company_id = sales_documents.company_id
    )
  );

drop policy if exists purchase_orders_creator_cleanup on public.purchase_orders;
create policy purchase_orders_creator_cleanup on public.purchase_orders
  for delete to authenticated
  using (
    created_by = (select auth.uid())
    and status = 'submitted'
    and not exists (
      select 1 from public.purchase_order_lines l
      where l.purchase_order_id = purchase_orders.id
        and l.company_id = purchase_orders.company_id
    )
  );

drop policy if exists purchase_requests_creator_cleanup on public.purchase_requests;
create policy purchase_requests_creator_cleanup on public.purchase_requests
  for delete to authenticated
  using (
    requested_by = (select auth.uid())
    and status = 'submitted'
    and not exists (
      select 1 from public.purchase_request_lines l
      where l.purchase_request_id = purchase_requests.id
        and l.company_id = purchase_requests.company_id
    )
  );

drop policy if exists products_creator_cleanup on public.products;
create policy products_creator_cleanup on public.products
  for delete to authenticated
  using (
    created_by = (select auth.uid())
    and not exists (select 1 from public.product_prices p where p.product_id = products.id and p.company_id = products.company_id)
    and not exists (select 1 from public.sales_document_lines l where l.product_id = products.id and l.company_id = products.company_id)
    and not exists (select 1 from public.purchase_order_lines l where l.product_id = products.id and l.company_id = products.company_id)
    and not exists (select 1 from public.purchase_request_lines l where l.product_id = products.id and l.company_id = products.company_id)
  );

commit;
