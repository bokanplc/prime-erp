-- Supporting indexes for new ERP foreign keys; applied 2026-10-25.
create index if not exists purchase_items_company_product_idx on public.purchase_document_items(company_id,product_id);
create index if not exists purchase_documents_created_by_idx on public.purchase_documents(created_by);
create index if not exists purchase_documents_company_supplier_idx on public.purchase_documents(company_id,supplier_id);
create index if not exists sales_payments_recorded_by_idx on public.sales_payments(recorded_by);
create index if not exists stock_movements_created_by_idx on public.stock_movements(created_by);
create index if not exists suppliers_created_by_idx on public.suppliers(created_by);
