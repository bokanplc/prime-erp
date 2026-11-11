-- Allow the designated data-entry role to record purchasing source data,
-- while retaining manager-only approval and delete controls.
begin;

drop policy if exists suppliers_purchasing_write on public.suppliers;
create policy suppliers_purchasing_write on public.suppliers
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]));

drop policy if exists suppliers_purchasing_update on public.suppliers;
create policy suppliers_purchasing_update on public.suppliers
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]));

drop policy if exists purchase_orders_purchasing_write on public.purchase_orders;
create policy purchase_orders_purchasing_write on public.purchase_orders
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]));

drop policy if exists purchase_orders_purchasing_update on public.purchase_orders;
create policy purchase_orders_purchasing_update on public.purchase_orders
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]));

drop policy if exists purchase_lines_purchasing_write on public.purchase_order_lines;
create policy purchase_lines_purchasing_write on public.purchase_order_lines
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]));

drop policy if exists purchase_lines_purchasing_update on public.purchase_order_lines;
create policy purchase_lines_purchasing_update on public.purchase_order_lines
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]));

drop policy if exists product_prices_sales_write on public.product_prices;
create policy product_prices_sales_write on public.product_prices
  for insert to authenticated
  with check (
    (price_type = 'sales' and private.has_company_role(company_id, array['owner','admin','manager','sales']::public.company_role[]))
    or
    (price_type = 'purchase' and private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]))
  );

drop policy if exists product_prices_sales_update on public.product_prices;
create policy product_prices_sales_update on public.product_prices
  for update to authenticated
  using (
    (price_type = 'sales' and private.has_company_role(company_id, array['owner','admin','manager','sales']::public.company_role[]))
    or
    (price_type = 'purchase' and private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]))
  )
  with check (
    (price_type = 'sales' and private.has_company_role(company_id, array['owner','admin','manager','sales']::public.company_role[]))
    or
    (price_type = 'purchase' and private.has_company_role(company_id, array['owner','admin','manager','purchasing','data_entry']::public.company_role[]))
  );

commit;
