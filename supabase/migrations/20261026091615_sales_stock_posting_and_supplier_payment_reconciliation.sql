-- Sales stock posting and supplier payments/reconciliation.
alter table public.sales_documents drop constraint if exists sales_documents_status_check;
alter table public.sales_documents add constraint sales_documents_status_check
 check (status = any (array['draft','submitted','approved','posted','partially_paid','paid','cancelled','void']));
alter table public.sales_document_items add column if not exists stock_issued_quantity numeric(14,3) not null default 0;
alter table public.sales_document_items drop constraint if exists sales_document_items_stock_issued_quantity_check;
alter table public.sales_document_items add constraint sales_document_items_stock_issued_quantity_check check (stock_issued_quantity >= 0 and stock_issued_quantity <= quantity);

create table if not exists public.supplier_payments (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 purchase_document_id uuid not null references public.purchase_documents(id) on delete restrict,
 supplier_id uuid not null references public.suppliers(id) on delete restrict,
 payment_date date not null default current_date,
 amount numeric(14,2) not null check (amount > 0),
 currency_code text not null default 'ETB',
 payment_method text not null check (payment_method in ('cash','bank_transfer','cheque','mobile_money','card','other')),
 reference_number text, notes text,
 reconciliation_status text not null default 'unreconciled' check (reconciliation_status in ('unreconciled','matched','reconciled','disputed')),
 bank_reference text, reconciled_at timestamptz, reconciled_by uuid, recorded_by uuid,
 created_at timestamptz not null default now()
);
create index if not exists supplier_payments_company_doc_idx on public.supplier_payments(company_id,purchase_document_id);
create index if not exists supplier_payments_company_date_idx on public.supplier_payments(company_id,payment_date);
create unique index if not exists supplier_payments_company_reference_uidx on public.supplier_payments(company_id,reference_number) where reference_number is not null and btrim(reference_number)<>'';
alter table public.supplier_payments enable row level security;
drop policy if exists supplier_payments_select_member on public.supplier_payments;
create policy supplier_payments_select_member on public.supplier_payments for select to authenticated using (private.has_company_membership(company_id));
drop policy if exists supplier_payments_insert_accounting on public.supplier_payments;
create policy supplier_payments_insert_accounting on public.supplier_payments for insert to authenticated with check (
 private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=supplier_payments.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant'));
drop policy if exists supplier_payments_update_accounting on public.supplier_payments;
create policy supplier_payments_update_accounting on public.supplier_payments for update to authenticated
 using (private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=supplier_payments.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant'))
 with check (private.can_manage_company(company_id) or exists(select 1 from public.company_memberships m where m.company_id=supplier_payments.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant'));
drop policy if exists supplier_payments_delete_manager on public.supplier_payments;
create policy supplier_payments_delete_manager on public.supplier_payments for delete to authenticated using (private.can_manage_company(company_id));
revoke all on public.supplier_payments from anon;
grant select,insert,update,delete on public.supplier_payments to authenticated;

create or replace function public.post_sales_document_stock(p_sales_document_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_doc public.sales_documents%rowtype; v_item record; v_count integer:=0; v_balance numeric;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select * into v_doc from public.sales_documents where id=p_sales_document_id for update;
 if not found then raise exception 'Sales document not found'; end if;
 if not private.has_company_membership(v_doc.company_id) then raise exception 'Active company membership required'; end if;
 if v_doc.document_type not in ('sales_invoice','invoice','sales_order','delivery_note') then raise exception 'This sales document type cannot issue stock'; end if;
 if v_doc.status not in ('approved','submitted') then raise exception 'Only submitted or approved sales documents can issue stock'; end if;
 for v_item in select si.id,si.product_id,si.quantity,si.stock_issued_quantity,si.description from public.sales_document_items si where si.document_id=p_sales_document_id and si.company_id=v_doc.company_id order by si.product_id,si.id for update loop
  if v_item.product_id is null then raise exception 'Link every stock-tracked sales line to a product before issuing stock'; end if;
  if v_item.stock_issued_quantity>0 then raise exception 'This sales document has already issued stock; duplicate posting is blocked'; end if;
  perform 1 from public.products p where p.id=v_item.product_id and p.company_id=v_doc.company_id for update;
  if not found then raise exception 'Product is missing or belongs to another company'; end if;
  select coalesce(b.quantity_on_hand,0) into v_balance from (select 1) seed left join public.inventory_stock_balances b on b.product_id=v_item.product_id and b.company_id=v_doc.company_id;
  if coalesce(v_balance,0)<v_item.quantity then raise exception 'Insufficient stock for %: available %, requested %',v_item.description,coalesce(v_balance,0),v_item.quantity; end if;
  insert into public.stock_movements(company_id,product_id,movement_type,quantity,unit_cost,reference_type,reference_id,notes,created_by)
  values(v_doc.company_id,v_item.product_id,'sale_issue',v_item.quantity,0,'sales_document',p_sales_document_id,'Stock issued for sales document '||v_doc.document_number,(select auth.uid()));
  update public.sales_document_items set stock_issued_quantity=quantity where id=v_item.id;
  v_count:=v_count+1;
 end loop;
 if v_count=0 then raise exception 'No sales line items found'; end if;
 update public.sales_documents set status='posted',updated_at=now() where id=p_sales_document_id;
 return jsonb_build_object('sales_document_id',p_sales_document_id,'lines_posted',v_count,'status','posted');
end; $$;
revoke all on function public.post_sales_document_stock(uuid) from public,anon;
grant execute on function public.post_sales_document_stock(uuid) to authenticated;

create or replace function public.record_supplier_payment(p_payment jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_company uuid; v_doc_id uuid; v_supplier uuid; v_amount numeric(14,2); v_paid numeric(14,2); v_doc public.purchase_documents%rowtype; v_payment_id uuid;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_payment)<>'object' then raise exception 'Payment object required'; end if;
 v_company:=nullif(p_payment->>'company_id','')::uuid; v_doc_id:=nullif(p_payment->>'purchase_document_id','')::uuid; v_supplier:=nullif(p_payment->>'supplier_id','')::uuid; v_amount:=nullif(p_payment->>'amount','')::numeric;
 if v_company is null or not private.has_company_membership(v_company) then raise exception 'Active company membership required'; end if;
 if not (private.can_manage_company(v_company) or exists(select 1 from public.company_memberships m where m.company_id=v_company and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant')) then raise exception 'Accounting permission required'; end if;
 if v_doc_id is null or v_supplier is null or v_amount is null or v_amount<=0 then raise exception 'Document, supplier and positive payment amount are required'; end if;
 select * into v_doc from public.purchase_documents where id=v_doc_id and company_id=v_company for update;
 if not found then raise exception 'Purchase document not found in this company'; end if;
 if v_doc.supplier_id is distinct from v_supplier then raise exception 'Supplier does not match purchase document'; end if;
 if v_doc.status in ('draft','cancelled','void') then raise exception 'Cannot pay a draft or cancelled purchase document'; end if;
 if v_doc.document_type='purchase_return' then raise exception 'Supplier payment cannot be applied to a purchase return'; end if;
 perform 1 from public.suppliers where id=v_supplier and company_id=v_company for update;
 if not found then raise exception 'Supplier not found in this company'; end if;
 select coalesce(sum(amount),0) into v_paid from public.supplier_payments where company_id=v_company and purchase_document_id=v_doc_id;
 if v_paid+v_amount>v_doc.grand_total then raise exception 'Payment exceeds outstanding supplier balance'; end if;
 insert into public.supplier_payments(company_id,purchase_document_id,supplier_id,payment_date,amount,currency_code,payment_method,reference_number,notes,recorded_by)
 values(v_company,v_doc_id,v_supplier,coalesce(nullif(p_payment->>'payment_date','')::date,current_date),v_amount,coalesce(nullif(p_payment->>'currency_code',''),v_doc.currency_code),coalesce(nullif(p_payment->>'payment_method',''),'bank_transfer'),nullif(btrim(p_payment->>'reference_number'),''),nullif(p_payment->>'notes',''),(select auth.uid())) returning id into v_payment_id;
 select coalesce(sum(amount),0) into v_paid from public.supplier_payments where company_id=v_company and purchase_document_id=v_doc_id;
 if v_paid>=v_doc.grand_total then update public.purchase_documents set status='paid',updated_at=now() where id=v_doc_id;
 elsif v_paid>0 and v_doc.status in ('received','partially_paid','paid') then update public.purchase_documents set status='partially_paid',updated_at=now() where id=v_doc_id; end if;
 return v_payment_id;
end; $$;
revoke all on function public.record_supplier_payment(jsonb) from public,anon;
grant execute on function public.record_supplier_payment(jsonb) to authenticated;

create or replace function public.reconcile_supplier_payment(p_payment_id uuid,p_bank_reference text,p_reconciled boolean default true)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_pay public.supplier_payments%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select * into v_pay from public.supplier_payments where id=p_payment_id for update;
 if not found then raise exception 'Supplier payment not found'; end if;
 if not private.has_company_membership(v_pay.company_id) then raise exception 'Active company membership required'; end if;
 if not (private.can_manage_company(v_pay.company_id) or exists(select 1 from public.company_memberships m where m.company_id=v_pay.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role='accountant')) then raise exception 'Accounting permission required'; end if;
 if p_reconciled and nullif(btrim(p_bank_reference),'') is null then raise exception 'Bank or statement reference is required to reconcile'; end if;
 update public.supplier_payments set reconciliation_status=case when p_reconciled then 'reconciled' else 'unreconciled' end,bank_reference=case when p_reconciled then btrim(p_bank_reference) else null end,reconciled_at=case when p_reconciled then now() else null end,reconciled_by=case when p_reconciled then (select auth.uid()) else null end where id=p_payment_id;
 return jsonb_build_object('payment_id',p_payment_id,'reconciliation_status',case when p_reconciled then 'reconciled' else 'unreconciled' end);
end; $$;
revoke all on function public.reconcile_supplier_payment(uuid,text,boolean) from public,anon;
grant execute on function public.reconcile_supplier_payment(uuid,text,boolean) to authenticated;

create or replace view public.supplier_payment_reconciliation with (security_invoker=true) as
select sp.id as payment_id,sp.company_id,sp.purchase_document_id,pd.document_number,sp.supplier_id,s.name as supplier_name,sp.payment_date,sp.amount,sp.currency_code,sp.payment_method,sp.reference_number,sp.bank_reference,sp.reconciliation_status,sp.reconciled_at,sp.notes,sp.recorded_by
from public.supplier_payments sp join public.purchase_documents pd on pd.id=sp.purchase_document_id and pd.company_id=sp.company_id join public.suppliers s on s.id=sp.supplier_id and s.company_id=sp.company_id;
revoke all on public.supplier_payment_reconciliation from anon;
grant select on public.supplier_payment_reconciliation to authenticated;
