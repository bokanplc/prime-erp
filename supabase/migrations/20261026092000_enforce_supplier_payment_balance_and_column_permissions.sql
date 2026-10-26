create or replace function private.validate_supplier_payment_insert()
returns trigger language plpgsql security invoker set search_path=''
as $$
declare v_doc public.purchase_documents%rowtype; v_paid numeric(14,2);
begin
 select * into v_doc from public.purchase_documents where id=new.purchase_document_id and company_id=new.company_id for update;
 if not found then raise exception 'Purchase document not found in this company'; end if;
 if v_doc.supplier_id is distinct from new.supplier_id then raise exception 'Supplier does not match purchase document'; end if;
 if v_doc.status in ('draft','cancelled','void') or v_doc.document_type='purchase_return' then raise exception 'Payments require a valid non-cancelled purchase document'; end if;
 if new.currency_code is distinct from v_doc.currency_code then raise exception 'Payment currency must match purchase document currency'; end if;
 select coalesce(sum(amount),0) into v_paid from public.supplier_payments where company_id=new.company_id and purchase_document_id=new.purchase_document_id;
 if v_paid+new.amount>v_doc.grand_total then raise exception 'Payment exceeds outstanding supplier balance'; end if;
 return new;
end; $$;
drop trigger if exists supplier_payment_validate_before_insert on public.supplier_payments;
create trigger supplier_payment_validate_before_insert before insert on public.supplier_payments for each row execute function private.validate_supplier_payment_insert();
revoke update on public.supplier_payments from authenticated;
grant update (reconciliation_status,bank_reference,reconciled_at,reconciled_by) on public.supplier_payments to authenticated;
