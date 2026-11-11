-- Cover the new same-company landed purchase-line reference.
create index if not exists idx_sales_document_lines_landed_po_line_company
  on public.sales_document_lines (landed_purchase_order_line_id, company_id);
