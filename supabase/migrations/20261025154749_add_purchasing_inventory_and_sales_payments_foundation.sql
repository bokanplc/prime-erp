-- Applied to Supabase project kafiwnuynjemufnankvi on 2026-10-25.
-- Purchasing, inventory ledger, and sales-payment foundation.
-- All exposed tables use company-scoped RLS; no anon access is granted.

create table if not exists public.suppliers (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 code text, name text not null, contact_person text, email text, phone text, tax_number text, address text, notes text,
 is_active boolean not null default true, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,id)
);
create unique index if not exists suppliers_company_code_unique on public.suppliers(company_id,code) where code is not null;
create index if not exists suppliers_company_name_idx on public.suppliers(company_id,name);

create table if not exists public.purchase_documents (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 supplier_id uuid, document_type text not null check(document_type in ('purchase_request','purchase_order','supplier_invoice','purchase_return')),
 document_number text not null, status text not null default 'draft' check(status in ('draft','submitted','approved','received','partially_paid','paid','cancelled','void')),
 document_date date not null default current_date, due_date date, currency_code text not null default 'ETB' check(length(currency_code)=3),
 subtotal numeric(14,2) not null default 0 check(subtotal>=0), tax_total numeric(14,2) not null default 0 check(tax_total>=0),
 discount_total numeric(14,2) not null default 0 check(discount_total>=0), grand_total numeric(14,2) not null default 0 check(grand_total>=0),
 notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), unique(company_id,id), unique(company_id,document_number),
 constraint purchase_documents_supplier_same_company_fk foreign key(company_id,supplier_id) references public.suppliers(company_id,id)
);
create index if not exists purchase_documents_company_date_idx on public.purchase_documents(company_id,document_date desc);
create index if not exists purchase_documents_company_status_idx on public.purchase_documents(company_id,status);

create table if not exists public.purchase_document_items (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 purchase_document_id uuid not null, product_id uuid, description text not null, quantity numeric(14,4) not null check(quantity>0),
 received_quantity numeric(14,4) not null default 0 check(received_quantity>=0 and received_quantity<=quantity),
 unit text not null default 'unit', unit_cost numeric(14,2) not null default 0 check(unit_cost>=0),
 tax_rate numeric(7,6) not null default 0 check(tax_rate>=0 and tax_rate<=1),
 line_subtotal numeric(14,2) not null default 0 check(line_subtotal>=0), line_tax numeric(14,2) not null default 0 check(line_tax>=0),
 line_total numeric(14,2) not null default 0 check(line_total>=0), created_at timestamptz not null default now(),
 constraint purchase_items_document_same_company_fk foreign key(company_id,purchase_document_id) references public.purchase_documents(company_id,id) on delete cascade,
 constraint purchase_items_product_same_company_fk foreign key(company_id,product_id) references public.products(company_id,id)
);
create index if not exists purchase_items_document_idx on public.purchase_document_items(company_id,purchase_document_id);

create table if not exists public.stock_movements (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 product_id uuid not null, movement_type text not null check(movement_type in ('opening','purchase_receipt','sale_issue','customer_return','supplier_return','adjustment_in','adjustment_out')),
 quantity numeric(14,4) not null check(quantity>0), unit_cost numeric(14,2) not null default 0 check(unit_cost>=0),
 reference_type text, reference_id uuid, movement_date timestamptz not null default now(), notes text,
 created_by uuid references auth.users(id) on delete set null,
 constraint stock_movements_product_same_company_fk foreign key(company_id,product_id) references public.products(company_id,id)
);
create index if not exists stock_movements_company_product_date_idx on public.stock_movements(company_id,product_id,movement_date desc);

create table if not exists public.sales_payments (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
 sales_document_id uuid not null, payment_date date not null default current_date, amount numeric(14,2) not null check(amount>0),
 currency_code text not null default 'ETB' check(length(currency_code)=3),
 payment_method text not null check(payment_method in ('cash','bank_transfer','mobile_money','card','cheque','other')),
 reference_number text, notes text, recorded_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
 constraint sales_payments_document_same_company_fk foreign key(company_id,sales_document_id) references public.sales_documents(company_id,id)
);
create index if not exists sales_payments_document_date_idx on public.sales_payments(company_id,sales_document_id,payment_date desc);

alter table public.suppliers enable row level security;
alter table public.purchase_documents enable row level security;
alter table public.purchase_document_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.sales_payments enable row level security;

-- The migration is recorded in Supabase's migration history. Policy names and predicates
-- below document the deployed access model; do not run this file over an already migrated
-- database without converting the policy statements to idempotent drop/create operations.
create policy suppliers_select_member on public.suppliers for select to authenticated using(private.has_company_membership(company_id));
create policy suppliers_insert_manager_inventory on public.suppliers for insert to authenticated with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=suppliers.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='inventory'));
create policy suppliers_update_manager_inventory on public.suppliers for update to authenticated using(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=suppliers.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='inventory')) with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=suppliers.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='inventory'));
create policy suppliers_delete_manager on public.suppliers for delete to authenticated using(private.can_manage_company(company_id));

create policy purchase_documents_select_member on public.purchase_documents for select to authenticated using(private.has_company_membership(company_id));
create policy purchase_documents_insert_purchasing on public.purchase_documents for insert to authenticated with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=purchase_documents.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('inventory','accountant')));
create policy purchase_documents_update_purchasing on public.purchase_documents for update to authenticated using(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=purchase_documents.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('inventory','accountant'))) with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=purchase_documents.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('inventory','accountant')));
create policy purchase_documents_delete_manager on public.purchase_documents for delete to authenticated using(private.can_manage_company(company_id));

create policy purchase_items_select_member on public.purchase_document_items for select to authenticated using(private.has_company_membership(company_id));
create policy purchase_items_insert_purchasing on public.purchase_document_items for insert to authenticated with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=purchase_document_items.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('inventory','accountant')));
create policy purchase_items_update_purchasing on public.purchase_document_items for update to authenticated using(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=purchase_document_items.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('inventory','accountant'))) with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=purchase_document_items.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('inventory','accountant')));
create policy purchase_items_delete_manager on public.purchase_document_items for delete to authenticated using(private.can_manage_company(company_id));

create policy stock_movements_select_member on public.stock_movements for select to authenticated using(private.has_company_membership(company_id));
create policy stock_movements_insert_inventory on public.stock_movements for insert to authenticated with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=stock_movements.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='inventory'));
create policy stock_movements_update_manager on public.stock_movements for update to authenticated using(private.can_manage_company(company_id)) with check(private.can_manage_company(company_id));
create policy stock_movements_delete_manager on public.stock_movements for delete to authenticated using(private.can_manage_company(company_id));

create policy sales_payments_select_member on public.sales_payments for select to authenticated using(private.has_company_membership(company_id));
create policy sales_payments_insert_accounting on public.sales_payments for insert to authenticated with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=sales_payments.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant'));
create policy sales_payments_update_accounting on public.sales_payments for update to authenticated using(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=sales_payments.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant')) with check(private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=sales_payments.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant'));
create policy sales_payments_delete_manager on public.sales_payments for delete to authenticated using(private.can_manage_company(company_id));

grant select,insert,update,delete on public.suppliers,public.purchase_documents,public.purchase_document_items,public.stock_movements,public.sales_payments to authenticated;
revoke all on public.suppliers,public.purchase_documents,public.purchase_document_items,public.stock_movements,public.sales_payments from anon;
