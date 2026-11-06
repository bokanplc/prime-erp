-- The target ERP now serves BlackRock Investment PLC only.
-- No rows use PRIME in this operational owner field; remove the decommissioned option.
alter table public.supply_shipments
  drop constraint if exists supply_shipments_purchasing_entity_check;
alter table public.supply_shipments
  add constraint supply_shipments_purchasing_entity_check
  check (purchasing_entity = any (array['BLACKROCK'::text, 'BOKAN Coordinated'::text]));
