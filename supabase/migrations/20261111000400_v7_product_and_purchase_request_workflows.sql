-- Product master and purchase request workflows. No inventory quantities or stock ledger.
begin;

create type public.product_price_type as enum ('purchase', 'sales');
create type public.sales_document_type as enum ('quotation', 'proforma', 'sales_order');
create type public.purchase_request_status as enum ('draft', 'submitted', 'approved', 'rejected', 'converted', 'cancelled');

create table public.products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  sku text,
  name text not null check (length(trim(name)) between 2 and 180),
  description text,
  unit_of_measure text not null,
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, sku),
  unique (id, company_id)
);

create table public.product_prices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  product_id uuid not null,
  price_type public.product_price_type not null,
  unit_price numeric(18,2) not null check (unit_price >= 0),
  currency_code text not null default 'ETB' check (currency_code = 'ETB'),
  vat_treatment public.vat_treatment not null default 'exclusive',
  vat_rate_bps integer not null default 1500 check (vat_rate_bps between 0 and 100000),
  effective_from date not null default current_date,
  effective_to date,
  source_reference text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  constraint product_prices_product_same_company_fk
    foreign key (product_id, company_id) references public.products(id, company_id),
  check (effective_to is null or effective_to >= effective_from)
);

alter table public.sales_documents
  add column document_type public.sales_document_type not null default 'proforma';

alter table public.sales_document_lines
  add column product_id uuid,
  add constraint sales_lines_product_same_company_fk
    foreign key (product_id, company_id) references public.products(id, company_id);

alter table public.purchase_order_lines
  add column product_id uuid,
  add constraint purchase_lines_product_same_company_fk
    foreign key (product_id, company_id) references public.products(id, company_id);

create table public.purchase_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  request_number text not null,
  supplier_id uuid,
  requested_date date not null default current_date,
  required_by date,
  status public.purchase_request_status not null default 'draft',
  reason text,
  notes text,
  requested_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, request_number),
  unique (id, company_id),
  foreign key (supplier_id, company_id) references public.suppliers(id, company_id),
  check (required_by is null or required_by >= requested_date)
);

create table public.purchase_request_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  purchase_request_id uuid not null,
  product_id uuid,
  description text not null,
  requested_quantity numeric(18,3) not null check (requested_quantity > 0),
  unit_of_measure text not null,
  estimated_unit_price numeric(18,2) check (estimated_unit_price is null or estimated_unit_price >= 0),
  created_at timestamptz not null default now(),
  foreign key (purchase_request_id, company_id) references public.purchase_requests(id, company_id) on delete cascade,
  foreign key (product_id, company_id) references public.products(id, company_id)
);

alter table public.products enable row level security;
alter table public.products force row level security;
alter table public.product_prices enable row level security;
alter table public.product_prices force row level security;
alter table public.purchase_requests enable row level security;
alter table public.purchase_requests force row level security;
alter table public.purchase_request_lines enable row level security;
alter table public.purchase_request_lines force row level security;

create policy products_member_read on public.products
  for select to authenticated using (private.is_company_member(company_id));
create policy products_workspace_insert on public.products
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']::public.company_role[]));
create policy products_workspace_update on public.products
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','data_entry']::public.company_role[]));
create policy products_manager_delete on public.products
  for delete to authenticated using (private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[]));

create policy product_prices_member_read on public.product_prices
  for select to authenticated using (private.is_company_member(company_id));
create policy product_prices_sales_write on public.product_prices
  for insert to authenticated
  with check (
    (price_type = 'sales' and private.has_company_role(company_id, array['owner','admin','manager','sales']::public.company_role[]))
    or
    (price_type = 'purchase' and private.has_company_role(company_id, array['owner','admin','manager','purchasing']::public.company_role[]))
  );
create policy product_prices_sales_update on public.product_prices
  for update to authenticated
  using (
    (price_type = 'sales' and private.has_company_role(company_id, array['owner','admin','manager','sales']::public.company_role[]))
    or
    (price_type = 'purchase' and private.has_company_role(company_id, array['owner','admin','manager','purchasing']::public.company_role[]))
  )
  with check (
    (price_type = 'sales' and private.has_company_role(company_id, array['owner','admin','manager','sales']::public.company_role[]))
    or
    (price_type = 'purchase' and private.has_company_role(company_id, array['owner','admin','manager','purchasing']::public.company_role[]))
  );
create policy product_prices_manager_delete on public.product_prices
  for delete to authenticated using (private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[]));

create policy purchase_requests_member_read on public.purchase_requests
  for select to authenticated using (private.is_company_member(company_id));
create policy purchase_requests_workspace_insert on public.purchase_requests
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[]));
create policy purchase_requests_workspace_update on public.purchase_requests
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','admin','manager','purchasing']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing']::public.company_role[]));
create policy purchase_requests_manager_delete on public.purchase_requests
  for delete to authenticated using (private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[]));

create policy purchase_request_lines_member_read on public.purchase_request_lines
  for select to authenticated using (private.is_company_member(company_id));
create policy purchase_request_lines_workspace_insert on public.purchase_request_lines
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[]));
create policy purchase_request_lines_workspace_update on public.purchase_request_lines
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','admin','manager','purchasing']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','admin','manager','purchasing']::public.company_role[]));
create policy purchase_request_lines_manager_delete on public.purchase_request_lines
  for delete to authenticated using (private.has_company_role(company_id, array['owner','admin','manager']::public.company_role[]));

grant select, insert, update, delete on public.products, public.product_prices,
  public.purchase_requests, public.purchase_request_lines to authenticated;

commit;
