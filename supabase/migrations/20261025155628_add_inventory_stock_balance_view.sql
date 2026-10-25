-- Read-only stock balance derived exclusively from recorded stock movements.
-- Uses security_invoker so the underlying stock_movements and products RLS policies apply.
create or replace view public.inventory_stock_balances
with (security_invoker = true)
as
select
  sm.company_id,
  sm.product_id,
  p.sku,
  p.name as product_name,
  p.unit,
  sum(case when sm.movement_type in ('opening','purchase_receipt','customer_return','adjustment_in') then sm.quantity
           when sm.movement_type in ('sale_issue','supplier_return','adjustment_out') then -sm.quantity
           else 0 end) as quantity_on_hand,
  max(sm.movement_date) as last_movement_at
from public.stock_movements sm
join public.products p
  on p.id = sm.product_id and p.company_id = sm.company_id
group by sm.company_id, sm.product_id, p.sku, p.name, p.unit;
revoke all on public.inventory_stock_balances from anon;
grant select on public.inventory_stock_balances to authenticated;
