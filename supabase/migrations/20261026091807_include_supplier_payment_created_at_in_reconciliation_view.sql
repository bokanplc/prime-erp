create or replace view public.supplier_payment_reconciliation with (security_invoker=true) as
select sp.id as payment_id,sp.company_id,sp.purchase_document_id,pd.document_number,sp.supplier_id,s.name as supplier_name,sp.payment_date,sp.amount,sp.currency_code,sp.payment_method,sp.reference_number,sp.bank_reference,sp.reconciliation_status,sp.reconciled_at,sp.notes,sp.recorded_by,sp.created_at
from public.supplier_payments sp join public.purchase_documents pd on pd.id=sp.purchase_document_id and pd.company_id=sp.company_id join public.suppliers s on s.id=sp.supplier_id and s.company_id=sp.company_id;
revoke all on public.supplier_payment_reconciliation from anon;
grant select on public.supplier_payment_reconciliation to authenticated;
