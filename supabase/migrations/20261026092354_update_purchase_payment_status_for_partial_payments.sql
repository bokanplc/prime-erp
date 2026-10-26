create or replace function private.refresh_purchase_payment_status()
returns trigger language plpgsql security invoker set search_path=''
as $$
declare v_doc public.purchase_documents%rowtype; v_paid numeric(14,2);
begin
 select * into v_doc from public.purchase_documents where id=new.purchase_document_id and company_id=new.company_id for update;
 if not found then return new; end if;
 select coalesce(sum(amount),0) into v_paid from public.supplier_payments where company_id=new.company_id and purchase_document_id=new.purchase_document_id;
 if v_paid>=v_doc.grand_total then
   update public.purchase_documents set status='paid',updated_at=now() where id=v_doc.id;
 elsif v_paid>0 and v_doc.status in ('approved','received','partially_received','partially_paid','paid') then
   update public.purchase_documents set status='partially_paid',updated_at=now() where id=v_doc.id;
 end if;
 return new;
end; $$;
drop trigger if exists supplier_payment_refresh_document_status on public.supplier_payments;
create trigger supplier_payment_refresh_document_status after insert on public.supplier_payments for each row execute function private.refresh_purchase_payment_status();
