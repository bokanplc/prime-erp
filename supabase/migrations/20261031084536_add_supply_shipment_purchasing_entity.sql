alter table public.supply_shipments
  add column purchasing_entity text not null default 'PRIME'
  check (purchasing_entity in ('PRIME','BLACKROCK','BOKAN Coordinated'));

comment on column public.supply_shipments.purchasing_entity is
  'Operational purchasing/coordinating entity selected in V6.7; company_id remains the authenticated legal-owner tenant.';
