create or replace function public.create_sales_document_with_items(p_document jsonb,p_items jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare v_document_id uuid; v_company_id uuid; v_sub numeric(14,2); v_tax numeric(14,2); v_discount numeric(14,2);
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_document)<>'object' or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'A document and at least one line item are required'; end if;
 v_company_id:=nullif(p_document->>'company_id','')::uuid;
 if v_company_id is null or not private.has_company_membership(v_company_id) then raise exception 'Active company membership required'; end if;
 if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,description text,quantity numeric,unit_price numeric,tax_rate numeric) where nullif(btrim(x.description),'') is null or x.quantity is null or x.quantity<=0 or x.unit_price is null or x.unit_price<0 or coalesce(x.tax_rate,0)<0 or coalesce(x.tax_rate,0)>1) then raise exception 'Invalid sales line item values'; end if;
 if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid) join public.products p on p.id=x.product_id where p.company_id<>v_company_id) then raise exception 'Product belongs to another company'; end if;
 select round(sum(round(x.quantity*x.unit_price,2)),2),round(sum(round(round(x.quantity*x.unit_price,2)*coalesce(x.tax_rate,0),2)),2) into v_sub,v_tax from jsonb_to_recordset(p_items) as x(product_id uuid,description text,quantity numeric,unit_price numeric,tax_rate numeric);
 v_discount:=coalesce(nullif(p_document->>'discount_total','')::numeric,0);
 if v_discount<0 or v_discount>v_sub+v_tax then raise exception 'Invalid discount'; end if;
 insert into public.sales_documents(company_id,customer_id,document_type,document_number,status,document_date,due_date,currency_code,subtotal,tax_total,discount_total,grand_total,notes,created_by)
 values(v_company_id,nullif(p_document->>'customer_id','')::uuid,p_document->>'document_type',p_document->>'document_number','draft',coalesce(nullif(p_document->>'document_date','')::date,current_date),nullif(p_document->>'due_date','')::date,coalesce(nullif(p_document->>'currency_code',''),'ETB'),v_sub,v_tax,v_discount,v_sub+v_tax-v_discount,nullif(p_document->>'notes',''),(select auth.uid())) returning id into v_document_id;
 insert into public.sales_document_items(company_id,document_id,product_id,description,quantity,unit,unit_price,tax_rate,line_subtotal,line_tax,line_total)
 select v_company_id,v_document_id,x.product_id,btrim(x.description),x.quantity,coalesce(nullif(x.unit,''),'unit'),x.unit_price,coalesce(x.tax_rate,0),round(x.quantity*x.unit_price,2),round(round(x.quantity*x.unit_price,2)*coalesce(x.tax_rate,0),2),round(round(x.quantity*x.unit_price,2)+round(round(x.quantity*x.unit_price,2)*coalesce(x.tax_rate,0),2),2)
 from jsonb_to_recordset(p_items) as x(product_id uuid,description text,quantity numeric,unit text,unit_price numeric,tax_rate numeric);
 return v_document_id;
end; $$;
revoke all on function public.create_sales_document_with_items(jsonb,jsonb) from public,anon;
grant execute on function public.create_sales_document_with_items(jsonb,jsonb) to authenticated;

create or replace function public.approve_sales_document(p_sales_document_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_doc public.sales_documents%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select * into v_doc from public.sales_documents where id=p_sales_document_id for update;
 if not found then raise exception 'Sales document not found'; end if;
 if not private.has_company_membership(v_doc.company_id) then raise exception 'Active company membership required'; end if;
 if not (private.can_manage_company(v_doc.company_id) or exists(select 1 from public.company_memberships m where m.company_id=v_doc.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('accountant','sales'))) then raise exception 'Sales approval permission required'; end if;
 if v_doc.document_type not in ('sales_order','invoice') then raise exception 'Only sales orders and invoices can be approved for stock posting'; end if;
 if v_doc.status<>'draft' then raise exception 'Only draft sales documents can be approved'; end if;
 if not exists(select 1 from public.sales_document_items where document_id=p_sales_document_id and company_id=v_doc.company_id) then raise exception 'Document has no line items'; end if;
 update public.sales_documents set status='approved',updated_at=now() where id=p_sales_document_id;
 return jsonb_build_object('sales_document_id',p_sales_document_id,'status','approved');
end; $$;
revoke all on function public.approve_sales_document(uuid) from public,anon;
grant execute on function public.approve_sales_document(uuid) to authenticated;

create or replace function public.approve_purchase_document(p_purchase_document_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_doc public.purchase_documents%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select * into v_doc from public.purchase_documents where id=p_purchase_document_id for update;
 if not found then raise exception 'Purchase document not found'; end if;
 if not private.has_company_membership(v_doc.company_id) then raise exception 'Active company membership required'; end if;
 if not (private.can_manage_company(v_doc.company_id) or exists(select 1 from public.company_memberships m where m.company_id=v_doc.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('accountant','inventory'))) then raise exception 'Purchase approval permission required'; end if;
 if v_doc.document_type not in ('purchase_order','supplier_invoice') then raise exception 'Only purchase orders and supplier invoices can be approved'; end if;
 if v_doc.status<>'draft' then raise exception 'Only draft purchase documents can be approved'; end if;
 if not exists(select 1 from public.purchase_document_items where purchase_document_id=p_purchase_document_id and company_id=v_doc.company_id) then raise exception 'Document has no line items'; end if;
 update public.purchase_documents set status='approved',updated_at=now() where id=p_purchase_document_id;
 return jsonb_build_object('purchase_document_id',p_purchase_document_id,'status','approved');
end; $$;
revoke all on function public.approve_purchase_document(uuid) from public,anon;
grant execute on function public.approve_purchase_document(uuid) to authenticated;
