create table if not exists public.transaction_costs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default private.current_company_id()
    references public.companies(id) on delete restrict,
  cost_date date not null default current_date,
  cost_class text not null default 'direct_sales_cost'
    check (cost_class = any (array['landed_cost','direct_sales_cost','operating_expense'])),
  category text not null
    check (length(btrim(category)) between 1 and 120),
  amount numeric(14,2) not null check (amount > 0),
  currency_code text not null default 'ETB'
    check (currency_code ~ '^[A-Z]{3}$'),
  recipient_name text,
  location text,
  related_document_type text
    check (related_document_type is null or related_document_type = any (array['purchase_document','sales_document','shipment','customer','other'])),
  related_reference text,
  description text not null default '',
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint transaction_costs_creator_membership_fk
    foreign key (company_id,created_by)
    references public.company_memberships(company_id,user_id) on delete restrict
);

create index if not exists idx_transaction_costs_company_date
  on public.transaction_costs(company_id,cost_date desc);
create index if not exists idx_transaction_costs_company_class_date
  on public.transaction_costs(company_id,cost_class,cost_date desc);
create index if not exists idx_transaction_costs_company_reference
  on public.transaction_costs(company_id,related_document_type,related_reference);
create index if not exists idx_transaction_costs_created_by
  on public.transaction_costs(created_by);

alter table public.transaction_costs enable row level security;
revoke all on public.transaction_costs from anon, public;
grant select,insert,update,delete on public.transaction_costs to authenticated;

create policy transaction_costs_select_member
  on public.transaction_costs for select to authenticated
  using (private.has_company_membership(company_id));

create policy transaction_costs_insert_member
  on public.transaction_costs for insert to authenticated
  with check (
    private.has_company_membership(company_id)
    and created_by = (select auth.uid())
  );

create policy transaction_costs_update_finance
  on public.transaction_costs for update to authenticated
  using (private.has_company_role(company_id,array['owner','admin','manager','accountant']))
  with check (private.has_company_role(company_id,array['owner','admin','manager','accountant']));

create policy transaction_costs_delete_finance
  on public.transaction_costs for delete to authenticated
  using (private.has_company_role(company_id,array['owner','admin','manager','accountant']));
