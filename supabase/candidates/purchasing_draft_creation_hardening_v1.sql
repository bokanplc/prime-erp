-- Forward-only hardening for atomic purchase document creation.
-- Draft creation must never let a caller self-approve by supplying a status field.
-- Apply only after disposable PostgreSQL tests and live catalog comparison pass.
create or replace function public.create_purchase_document_with_items(p_document jsonb, p_items jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
 v_company uuid;
 v_doc uuid;
 v_sub numeric(14,2);
 v_tax numeric(14,2);
 v_discount numeric(14,2);
 v_type text;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_document) <> 'object' or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then
   raise exception 'A document object and at least one item are required';
 end if;

 v_company := nullif(p_document->>'company_id','')::uuid;
 if v_company is null or not private.has_company_membership(v_company) then
   raise exception 'Active company membership required';
 end if;
 if not (
   private.can_manage_company(v_company)
   or exists (
     select 1 from public.company_memberships m
      where m.company_id=v_company and m.user_id=(select auth.uid())
        and m.is_active and m.role in ('inventory','accountant')
   )
 ) then raise exception 'Purchasing permission required'; end if;

 v_type := nullif(btrim(p_document->>'document_type'),'');
 if v_type not in ('purchase_request','purchase_order','supplier_invoice','purchase_return') then
   raise exception 'Unsupported purchase document type';
 end if;
 if nullif(btrim(p_document->>'document_number'),'') is null then
   raise exception 'Purchase document number is required';
 end if;

 if exists (
   select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,description text,quantity numeric,unit text,unit_cost numeric,tax_rate numeric)
   where nullif(btrim(x.description),'') is null or x.quantity is null or x.quantity<=0
      or x.unit_cost is null or x.unit_cost<0
      or coalesce(x.tax_rate,0)<0 or coalesce(x.tax_rate,0)>1
 ) then raise exception 'Invalid purchase item values'; end if;

 select round(sum(round(x.quantity*x.unit_cost,2)),2),
        round(sum(round(round(x.quantity*x.unit_cost,2)*coalesce(x.tax_rate,0),2)),2)
 into v_sub,v_tax
 from jsonb_to_recordset(p_items) as x(product_id uuid,description text,quantity numeric,unit text,unit_cost numeric,tax_rate numeric);

 v_discount := coalesce(nullif(p_document->>'discount_total','')::numeric,0);
 if v_discount<0 or v_discount>v_sub+v_tax then raise exception 'Invalid discount'; end if;

 insert into public.purchase_documents(company_id,supplier_id,document_type,document_number,status,document_date,due_date,currency_code,subtotal,tax_total,discount_total,grand_total,notes,created_by)
 values(v_company,nullif(p_document->>'supplier_id','')::uuid,v_type,btrim(p_document->>'document_number'),
 'draft',coalesce(nullif(p_document->>'document_date','')::date,current_date),
 nullif(p_document->>'due_date','')::date,coalesce(nullif(p_document->>'currency_code',''),'ETB'),
 v_sub,v_tax,v_discount,v_sub+v_tax-v_discount,nullif(p_document->>'notes',''),(select auth.uid()))
 returning id into v_doc;

 insert into public.purchase_document_items(company_id,purchase_document_id,product_id,description,quantity,unit,unit_cost,tax_rate,line_subtotal,line_tax,line_total)
 select v_company,v_doc,x.product_id,btrim(x.description),x.quantity,coalesce(nullif(x.unit,''),'unit'),x.unit_cost,coalesce(x.tax_rate,0),
 round(x.quantity*x.unit_cost,2),round(round(x.quantity*x.unit_cost,2)*coalesce(x.tax_rate,0),2),
 round(round(x.quantity*x.unit_cost,2)+round(round(x.quantity*x.unit_cost,2)*coalesce(x.tax_rate,0),2),2)
 from jsonb_to_recordset(p_items) as x(product_id uuid,description text,quantity numeric,unit text,unit_cost numeric,tax_rate numeric);

 return v_doc;
end;
$$;
revoke all on function public.create_purchase_document_with_items(jsonb,jsonb) from public,anon;
grant execute on function public.create_purchase_document_with_items(jsonb,jsonb) to authenticated;
