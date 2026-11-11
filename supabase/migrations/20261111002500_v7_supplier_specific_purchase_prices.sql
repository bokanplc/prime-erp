-- Support supplier-specific purchase price history, parallel to customer-specific sales prices.
begin;

alter table public.product_prices
  add column supplier_id uuid,
  add constraint product_prices_supplier_same_company_fk
    foreign key (supplier_id, company_id)
    references public.suppliers(id, company_id),
  add constraint product_prices_party_matches_type_check
    check (
      (customer_id is null or price_type = 'sales')
      and (supplier_id is null or price_type = 'purchase')
      and not (customer_id is not null and supplier_id is not null)
    );

create index if not exists idx_product_prices_supplier_company
  on public.product_prices (supplier_id, company_id);

comment on column public.product_prices.supplier_id is
  'Optional supplier-specific purchase price. NULL denotes the general company purchase price.';

commit;
