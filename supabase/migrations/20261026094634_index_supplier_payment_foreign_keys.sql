-- Cover the supplier payment foreign keys with indexes for joins and deletes.
create index if not exists supplier_payments_purchase_document_id_idx
  on public.supplier_payments(purchase_document_id);

create index if not exists supplier_payments_supplier_id_idx
  on public.supplier_payments(supplier_id);
