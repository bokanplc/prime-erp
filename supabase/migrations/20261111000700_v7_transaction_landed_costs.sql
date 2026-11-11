-- Add a traceable, transaction-level landed unit cost for commercial margin analysis.
-- This is not inventory costing: no stock quantities, balances or valuation are introduced.
begin;

alter table public.purchase_order_lines
  add constraint purchase_order_lines_id_company_unique unique (id, company_id);

alter table public.sales_document_lines
  add column landed_unit_cost numeric(18,2)
    check (landed_unit_cost is null or landed_unit_cost >= 0),
  add column landed_cost_reference text,
  add column landed_purchase_order_line_id uuid,
  add constraint sales_lines_landed_po_line_same_company_fk
    foreign key (landed_purchase_order_line_id, company_id)
    references public.purchase_order_lines(id, company_id);

comment on column public.sales_document_lines.landed_unit_cost is
  'Normalized landed cost per sales unit in ETB, including non-recoverable VAT and excluding recoverable VAT. Used only for transaction margin analysis; never an inventory valuation.';
comment on column public.sales_document_lines.landed_cost_reference is
  'Supplier invoice, purchase order line or other source reference supporting the manually verified landed unit cost.';

commit;
