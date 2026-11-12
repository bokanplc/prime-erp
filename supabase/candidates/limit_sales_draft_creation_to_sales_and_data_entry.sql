-- Keep accounting-role access outside BOKAN ERP sales entry; Peachtree remains the accounting/payment system.
-- Draft creation only. This changes permissions, not business data.
CREATE OR REPLACE FUNCTION public.create_sales_document_with_items(
  p_document jsonb,
  p_items jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_document_id uuid;
  v_company_id uuid;
  v_customer_id uuid;
  v_salesperson_id uuid;
  v_customer_rep uuid;
  v_role text;
  v_sub numeric(14,2);
  v_tax numeric(14,2);
  v_discount numeric(14,2);
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF jsonb_typeof(p_document) IS DISTINCT FROM 'object'
     OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'A document and at least one line item are required';
  END IF;

  v_company_id := nullif(p_document->>'company_id','')::uuid;
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Company is required';
  END IF;

  SELECT m.role
    INTO v_role
    FROM public.company_memberships m
   WHERE m.company_id = v_company_id
     AND m.user_id = (SELECT auth.uid())
     AND m.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active company membership required';
  END IF;

  IF v_role NOT IN ('sales','staff')
     AND NOT private.can_manage_company(v_company_id) THEN
    RAISE EXCEPTION 'Sales or data-entry permission required to create a draft';
  END IF;

  IF coalesce(p_document->>'document_type','') NOT IN ('sales_order','invoice') THEN
    RAISE EXCEPTION 'Only sales orders and invoices can be created through this workflow';
  END IF;

  IF nullif(btrim(p_document->>'document_number'),'') IS NULL THEN
    RAISE EXCEPTION 'Document number is required';
  END IF;

  v_customer_id := nullif(p_document->>'customer_id','')::uuid;
  IF v_customer_id IS NOT NULL THEN
    SELECT c.assigned_rep
      INTO v_customer_rep
      FROM public.customers c
     WHERE c.id = v_customer_id
       AND c.company_id = v_company_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Customer is missing or belongs to another company';
    END IF;
  END IF;

  v_salesperson_id := nullif(p_document->>'salesperson_id','')::uuid;

  IF v_role = 'sales' THEN
    IF v_salesperson_id IS NULL THEN
      v_salesperson_id := (SELECT auth.uid());
    END IF;
    IF v_salesperson_id <> (SELECT auth.uid()) THEN
      RAISE EXCEPTION 'Sales representatives may only create drafts for themselves';
    END IF;
  ELSIF v_salesperson_id IS NULL THEN
    v_salesperson_id := v_customer_rep;
  END IF;

  IF v_salesperson_id IS NULL OR NOT EXISTS (
    SELECT 1
      FROM public.company_memberships m
     WHERE m.company_id = v_company_id
       AND m.user_id = v_salesperson_id
       AND m.is_active
       AND m.role = 'sales'
  ) THEN
    RAISE EXCEPTION 'An active sales representative must be assigned to the draft';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM jsonb_to_recordset(p_items)
           AS x(product_id uuid, description text, quantity numeric,
                unit_price numeric, tax_rate numeric)
     WHERE nullif(btrim(x.description),'') IS NULL
        OR x.quantity IS NULL OR x.quantity <= 0
        OR x.unit_price IS NULL OR x.unit_price < 0
        OR coalesce(x.tax_rate,0) < 0 OR coalesce(x.tax_rate,0) > 1
  ) THEN
    RAISE EXCEPTION 'Invalid sales line item values';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM jsonb_to_recordset(p_items)
           AS x(product_id uuid)
      LEFT JOIN public.products p
        ON p.id = x.product_id
       AND p.company_id = v_company_id
     WHERE x.product_id IS NOT NULL
       AND p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'Product is missing or belongs to another company';
  END IF;

  SELECT round(sum(round(x.quantity*x.unit_price,2)),2),
         round(sum(round(round(x.quantity*x.unit_price,2)*coalesce(x.tax_rate,0),2)),2)
    INTO v_sub,v_tax
    FROM jsonb_to_recordset(p_items)
         AS x(product_id uuid,description text,quantity numeric,
              unit_price numeric,tax_rate numeric);

  v_discount := coalesce(nullif(p_document->>'discount_total','')::numeric,0);
  IF v_discount < 0 OR v_discount > v_sub + v_tax THEN
    RAISE EXCEPTION 'Invalid discount';
  END IF;

  INSERT INTO public.sales_documents(
    company_id, customer_id, salesperson_id, document_type, document_number,
    status, document_date, due_date, currency_code, subtotal, tax_total,
    discount_total, grand_total, notes, created_by
  )
  VALUES (
    v_company_id, v_customer_id, v_salesperson_id,
    p_document->>'document_type', btrim(p_document->>'document_number'),
    'draft',
    coalesce(nullif(p_document->>'document_date','')::date,current_date),
    nullif(p_document->>'due_date','')::date,
    coalesce(nullif(p_document->>'currency_code',''),'ETB'),
    v_sub, v_tax, v_discount, v_sub + v_tax - v_discount,
    nullif(p_document->>'notes',''), (SELECT auth.uid())
  )
  RETURNING id INTO v_document_id;

  INSERT INTO public.sales_document_items(
    company_id, document_id, product_id, description, quantity, unit,
    unit_price, tax_rate, line_subtotal, line_tax, line_total
  )
  SELECT
    v_company_id, v_document_id, x.product_id, btrim(x.description),
    x.quantity, coalesce(nullif(x.unit,''),'unit'), x.unit_price,
    coalesce(x.tax_rate,0), round(x.quantity*x.unit_price,2),
    round(round(x.quantity*x.unit_price,2)*coalesce(x.tax_rate,0),2),
    round(round(x.quantity*x.unit_price,2)
      + round(round(x.quantity*x.unit_price,2)*coalesce(x.tax_rate,0),2),2)
  FROM jsonb_to_recordset(p_items)
       AS x(product_id uuid,description text,quantity numeric,unit text,
            unit_price numeric,tax_rate numeric);

  RETURN v_document_id;
END;
$function$;


REVOKE ALL ON FUNCTION public.create_sales_document_with_items(jsonb,jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_sales_document_with_items(jsonb,jsonb)
  TO authenticated;
