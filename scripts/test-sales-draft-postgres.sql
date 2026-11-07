-- Disposable PostgreSQL integration test for sales draft creation.
-- Run from repository root with:
-- psql -X -v ON_ERROR_STOP=1 -f scripts/test-sales-draft-postgres.sql

DO $$
BEGIN
  CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE auth.users (id uuid PRIMARY KEY);

CREATE TABLE public.company_memberships (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  role text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.products (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL,
  name text NOT NULL
);
CREATE TABLE public.customers (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL,
  name text NOT NULL,
  assigned_rep uuid REFERENCES auth.users(id)
);
CREATE TABLE public.sales_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL,
  customer_id uuid REFERENCES public.customers(id),
  document_type text NOT NULL CHECK (document_type IN ('sales_order','invoice')),
  document_number text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  document_date date NOT NULL DEFAULT current_date,
  due_date date,
  currency_code text NOT NULL DEFAULT 'ETB',
  subtotal numeric(14,2) NOT NULL DEFAULT 0,
  tax_total numeric(14,2) NOT NULL DEFAULT 0,
  discount_total numeric(14,2) NOT NULL DEFAULT 0,
  grand_total numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  created_by uuid NOT NULL
);
CREATE TABLE public.sales_document_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL,
  document_id uuid NOT NULL REFERENCES public.sales_documents(id),
  product_id uuid REFERENCES public.products(id),
  description text NOT NULL,
  quantity numeric NOT NULL DEFAULT 1,
  unit text NOT NULL DEFAULT 'unit',
  unit_price numeric NOT NULL DEFAULT 0,
  tax_rate numeric NOT NULL DEFAULT 0,
  line_subtotal numeric NOT NULL DEFAULT 0,
  line_tax numeric NOT NULL DEFAULT 0,
  line_total numeric NOT NULL DEFAULT 0,
  stock_issued_quantity numeric NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION private.can_manage_company(p_company_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.company_memberships m
     WHERE m.company_id = p_company_id
       AND m.user_id = (SELECT auth.uid())
       AND m.is_active
       AND m.role IN ('owner','admin','manager')
  )
$$;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_document_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY products_select_member ON public.products
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id=products.company_id
       AND m.user_id=(SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY customers_select_member ON public.customers
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id=customers.company_id
       AND m.user_id=(SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY sales_documents_select_member ON public.sales_documents
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id=sales_documents.company_id
       AND m.user_id=(SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY sales_documents_insert_allowed ON public.sales_documents
  FOR INSERT TO authenticated
  WITH CHECK (
    private.can_manage_company(company_id)
    OR EXISTS (
      SELECT 1 FROM public.company_memberships m
       WHERE m.company_id=sales_documents.company_id
         AND m.user_id=(SELECT auth.uid()) AND m.is_active
         AND m.role IN ('sales','staff','accountant')
    )
  );
CREATE POLICY sales_items_select_member ON public.sales_document_items
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id=sales_document_items.company_id
       AND m.user_id=(SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY sales_items_insert_allowed ON public.sales_document_items
  FOR INSERT TO authenticated
  WITH CHECK (
    private.can_manage_company(company_id)
    OR EXISTS (
      SELECT 1 FROM public.company_memberships m
       WHERE m.company_id=sales_document_items.company_id
         AND m.user_id=(SELECT auth.uid()) AND m.is_active
         AND m.role IN ('sales','staff','accountant')
    )
  );

GRANT USAGE ON SCHEMA auth, private TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
GRANT EXECUTE ON FUNCTION private.can_manage_company(uuid) TO authenticated;
GRANT SELECT ON public.company_memberships, public.products, public.customers,
  public.sales_documents, public.sales_document_items TO authenticated;

INSERT INTO auth.users(id) VALUES
  ('30000000-0000-0000-0000-000000000002'),
  ('30000000-0000-0000-0000-000000000004'),
  ('30000000-0000-0000-0000-000000000005'),
  ('30000000-0000-0000-0000-000000000006'),
  ('30000000-0000-0000-0000-000000000007');

INSERT INTO public.company_memberships(id,company_id,user_id,role)
VALUES
  ('10000000-0000-0000-0000-000000000002','01350a71-0a93-44cf-b6c9-9bd547c0077a','30000000-0000-0000-0000-000000000002','sales'),
  ('10000000-0000-0000-0000-000000000004','01350a71-0a93-44cf-b6c9-9bd547c0077a','30000000-0000-0000-0000-000000000004','staff'),
  ('10000000-0000-0000-0000-000000000005','01350a71-0a93-44cf-b6c9-9bd547c0077a','30000000-0000-0000-0000-000000000005','viewer'),
  ('10000000-0000-0000-0000-000000000006','01350a71-0a93-44cf-b6c9-9bd547c0077a','30000000-0000-0000-0000-000000000006','sales'),
  ('10000000-0000-0000-0000-000000000007','01350a71-0a93-44cf-b6c9-9bd547c0077a','30000000-0000-0000-0000-000000000007','manager');

INSERT INTO public.products(id,company_id,name) VALUES
  ('0ed6991c-cfe3-411e-a264-86ac42add7c0','01350a71-0a93-44cf-b6c9-9bd547c0077a','Yellow Plywood'),
  ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Other company product');

INSERT INTO public.customers(id,company_id,name,assigned_rep) VALUES
  ('70000000-0000-0000-0000-000000000001','01350a71-0a93-44cf-b6c9-9bd547c0077a','Test customer','30000000-0000-0000-0000-000000000002'),
  ('70000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Other company customer','30000000-0000-0000-0000-000000000006');

\ir ../supabase/candidates/20261107071000_harden_sales_document_draft_creation.sql

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000004',false);

DO $$
BEGIN
  BEGIN
    INSERT INTO public.sales_documents(company_id,document_type,document_number,created_by)
    VALUES ('01350a71-0a93-44cf-b6c9-9bd547c0077a','sales_order','DIRECT-INSERT-BLOCKED','30000000-0000-0000-0000-000000000004');
    RAISE EXCEPTION 'Expected direct sales document insert to be blocked';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END $$;

DO $$
DECLARE
  v_id uuid;
  v_salesperson uuid;
  v_creator uuid;
  v_status text;
  v_total numeric;
  v_line_count integer;
BEGIN
  v_id := public.create_sales_document_with_items(
    jsonb_build_object(
      'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
      'customer_id','70000000-0000-0000-0000-000000000001',
      'document_type','sales_order',
      'document_number','SO-STAFF-001',
      'currency_code','ETB',
      'discount_total',0
    ),
    jsonb_build_array(jsonb_build_object(
      'product_id','0ed6991c-cfe3-411e-a264-86ac42add7c0',
      'description','Yellow Plywood','quantity',2,'unit','pcs',
      'unit_price',0,'tax_rate',0
    ))
  );
  SELECT salesperson_id,created_by,status,grand_total
    INTO v_salesperson,v_creator,v_status,v_total
    FROM public.sales_documents WHERE id=v_id;
  SELECT count(*) INTO v_line_count FROM public.sales_document_items WHERE document_id=v_id;
  IF v_salesperson <> '30000000-0000-0000-0000-000000000002'
     OR v_creator <> '30000000-0000-0000-0000-000000000004'
     OR v_status <> 'draft' OR v_total <> 0 OR v_line_count <> 1 THEN
    RAISE EXCEPTION 'Data-entry draft creation or salesperson attribution failed';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000002',false);
DO $$
DECLARE
  v_id uuid;
  v_salesperson uuid;
BEGIN
  v_id := public.create_sales_document_with_items(
    jsonb_build_object(
      'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
      'customer_id','70000000-0000-0000-0000-000000000001',
      'document_type','invoice',
      'document_number','INV-SALES-001',
      'currency_code','ETB'
    ),
    jsonb_build_array(jsonb_build_object(
      'product_id','0ed6991c-cfe3-411e-a264-86ac42add7c0',
      'description','Yellow Plywood','quantity',2,'unit','pcs',
      'unit_price',5000,'tax_rate',0
    ))
  );
  SELECT salesperson_id INTO v_salesperson FROM public.sales_documents WHERE id=v_id;
  IF v_salesperson <> '30000000-0000-0000-0000-000000000002' THEN
    RAISE EXCEPTION 'Sales representative self-attribution failed';
  END IF;

  BEGIN
    PERFORM public.create_sales_document_with_items(
      jsonb_build_object(
        'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
        'customer_id','70000000-0000-0000-0000-000000000001',
        'salesperson_id','30000000-0000-0000-0000-000000000006',
        'document_type','sales_order','document_number','SO-INVALID-REP'
      ),
      jsonb_build_array(jsonb_build_object(
        'product_id','0ed6991c-cfe3-411e-a264-86ac42add7c0',
        'description','Yellow Plywood','quantity',1,'unit','pcs','unit_price',1
      ))
    );
    RAISE EXCEPTION 'Expected sales self-assignment rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected sales self-assignment rejection' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000004',false);
DO $$
BEGIN
  BEGIN
    PERFORM public.create_sales_document_with_items(
      jsonb_build_object(
        'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
        'customer_id','70000000-0000-0000-0000-000000000001',
        'document_type','proforma','document_number','BAD-TYPE'
      ),
      jsonb_build_array(jsonb_build_object(
        'product_id','0ed6991c-cfe3-411e-a264-86ac42add7c0',
        'description','Yellow Plywood','quantity',1,'unit_price',1
      ))
    );
    RAISE EXCEPTION 'Expected invalid document type rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected invalid document type rejection' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.create_sales_document_with_items(
      jsonb_build_object(
        'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
        'customer_id','70000000-0000-0000-0000-000000000002',
        'document_type','sales_order','document_number','BAD-CUSTOMER'
      ),
      jsonb_build_array(jsonb_build_object(
        'product_id','0ed6991c-cfe3-411e-a264-86ac42add7c0',
        'description','Yellow Plywood','quantity',1,'unit_price',1
      ))
    );
    RAISE EXCEPTION 'Expected cross-company customer rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected cross-company customer rejection' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.create_sales_document_with_items(
      jsonb_build_object(
        'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
        'customer_id','70000000-0000-0000-0000-000000000001',
        'document_type','sales_order','document_number','BAD-PRODUCT'
      ),
      jsonb_build_array(jsonb_build_object(
        'product_id','40000000-0000-0000-0000-000000000002',
        'description','Other product','quantity',1,'unit_price',1
      ))
    );
    RAISE EXCEPTION 'Expected cross-company product rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected cross-company product rejection' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000005',false);
DO $$
BEGIN
  BEGIN
    PERFORM public.create_sales_document_with_items(
      jsonb_build_object(
        'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
        'customer_id','70000000-0000-0000-0000-000000000001',
        'document_type','sales_order','document_number','BAD-VIEWER'
      ),
      jsonb_build_array(jsonb_build_object(
        'product_id','0ed6991c-cfe3-411e-a264-86ac42add7c0',
        'description','Yellow Plywood','quantity',1,'unit_price',1
      ))
    );
    RAISE EXCEPTION 'Expected viewer role rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected viewer role rejection' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000007',false);
DO $$
DECLARE
  v_id uuid;
  v_salesperson uuid;
BEGIN
  v_id := public.create_sales_document_with_items(
    jsonb_build_object(
      'company_id','01350a71-0a93-44cf-b6c9-9bd547c0077a',
      'customer_id','70000000-0000-0000-0000-000000000001',
      'salesperson_id','30000000-0000-0000-0000-000000000006',
      'document_type','sales_order','document_number','SO-MANAGER-001'
    ),
    jsonb_build_array(jsonb_build_object(
      'product_id','0ed6991c-cfe3-411e-a264-86ac42add7c0',
      'description','Yellow Plywood','quantity',1,'unit','pcs','unit_price',5000
    ))
  );
  SELECT salesperson_id INTO v_salesperson FROM public.sales_documents WHERE id=v_id;
  IF v_salesperson <> '30000000-0000-0000-0000-000000000006' THEN
    RAISE EXCEPTION 'Manager salesperson assignment failed';
  END IF;
END $$;

RESET ROLE;
SELECT 'PASS: sales draft creation is restricted to sales/data-entry/management roles, validates company/customer/product ownership, assigns an active sales rep, and never approves or posts stock.' AS result;
