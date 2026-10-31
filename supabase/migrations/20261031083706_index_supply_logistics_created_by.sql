-- Index creator foreign keys for the company-scoped Supply & Logistics slice.
-- The company_id leading indexes are already covered by the operational indexes.
create index if not exists supply_shipments_created_by_idx
  on public.supply_shipments (created_by);
create index if not exists delivery_orders_created_by_idx
  on public.delivery_orders (created_by);
