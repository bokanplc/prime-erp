-- Support general and customer-specific sales prices without importing legacy price data.
begin;

alter table public.product_prices
  add column customer_id uuid,
  add constraint product_prices_customer_same_company_fk
    foreign key (customer_id, company_id)
    references public.customers(id, company_id);

create index if not exists idx_product_prices_customer_product_effective
  on public.product_prices (company_id, customer_id, product_id, price_type, effective_from desc);

comment on column public.product_prices.customer_id is
  'Optional customer-specific price. NULL denotes the general company price.';

commit;
