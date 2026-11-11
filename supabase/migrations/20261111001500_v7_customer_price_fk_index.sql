-- Cover the same-company customer reference added to product price history.
create index if not exists idx_product_prices_customer_company
  on public.product_prices (customer_id, company_id);
