-- Disposable PostgreSQL integration test for the atomic purchase-receiving RPC.
-- Run from repository root with psql -X -v ON_ERROR_STOP=1 -f scripts/test-purchase-receiving-postgres.sql

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

CREATE TABLE public.companies (
  id uuid PRIMARY KEY,
  name text NOT NULL
);
CREATE TABLE public.company_memberships (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.products (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL,
  name text NOT NULL
);
CREATE TABLE public.purchase_documents (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL,
  document_type text NOT NULL,
  document_number text NOT NULL,
  status text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.purchase_document_items (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL,
  purchase_document_id uuid NOT NULL REFERENCES public.purchase_documents(id),
  product_id uuid,
  description text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  received_quantity numeric NOT NULL DEFAULT 0,
  unit_cost numeric NOT NULL DEFAULT 0
);
CREATE TABLE public.stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL,
  product_id uuid NOT NULL,
  movement_type text NOT NULL,
  quantity numeric NOT NULL,
  unit_cost numeric NOT NULL,
  reference_type text,
  reference_id uuid,
  notes text,
  created_by uuid,
  movement_date timestamptz NOT NULL DEFAULT now()
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
       AND m.role IN ('owner', 'admin', 'manager')
  )
$$;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_document_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY products_select_member
  ON public.products FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = products.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY products_update_inventory
  ON public.products FOR UPDATE TO authenticated
  USING (private.can_manage_company(company_id) OR EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = products.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active AND m.role = 'inventory'
  ))
  WITH CHECK (private.can_manage_company(company_id) OR EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = products.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active AND m.role = 'inventory'
  ));
CREATE POLICY purchase_documents_select_member
  ON public.purchase_documents FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = purchase_documents.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY purchase_documents_update_inventory
  ON public.purchase_documents FOR UPDATE TO authenticated
  USING (private.can_manage_company(company_id) OR EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = purchase_documents.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active AND m.role = 'inventory'
  ))
  WITH CHECK (private.can_manage_company(company_id) OR EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = purchase_documents.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active AND m.role = 'inventory'
  ));
CREATE POLICY purchase_items_select_member
  ON public.purchase_document_items FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = purchase_document_items.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY purchase_items_update_inventory
  ON public.purchase_document_items FOR UPDATE TO authenticated
  USING (private.can_manage_company(company_id) OR EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = purchase_document_items.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active AND m.role = 'inventory'
  ))
  WITH CHECK (private.can_manage_company(company_id) OR EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = purchase_document_items.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active AND m.role = 'inventory'
  ));
CREATE POLICY stock_movements_select_member
  ON public.stock_movements FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = stock_movements.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active
  ));
CREATE POLICY stock_movements_insert_inventory
  ON public.stock_movements FOR INSERT TO authenticated
  WITH CHECK (private.can_manage_company(company_id) OR EXISTS (
    SELECT 1 FROM public.company_memberships m
     WHERE m.company_id = stock_movements.company_id
       AND m.user_id = (SELECT auth.uid()) AND m.is_active AND m.role = 'inventory'
  ));

GRANT USAGE ON SCHEMA auth, private TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
GRANT EXECUTE ON FUNCTION private.can_manage_company(uuid) TO authenticated;
GRANT SELECT ON public.company_memberships, public.products,
  public.purchase_documents, public.purchase_document_items, public.stock_movements
  TO authenticated;
GRANT UPDATE ON public.products, public.purchase_documents, public.purchase_document_items TO authenticated;
GRANT INSERT ON public.stock_movements TO authenticated;

\ir ../supabase/candidates/20261107070000_harden_atomic_purchase_receiving_workflow.sql

INSERT INTO public.companies(id,name)
VALUES ('01350a71-0a93-44cf-b6c9-9bd547c0077a','BlackRock Investment PLC');

INSERT INTO public.company_memberships(id, company_id, user_id, role)
VALUES
  ('10000000-0000-0000-0000-000000000001','01350a71-0a93-44cf-b6c9-9bd547c0077a','30000000-0000-0000-0000-000000000001','inventory'),
  ('10000000-0000-0000-0000-000000000002','01350a71-0a93-44cf-b6c9-9bd547c0077a','30000000-0000-0000-0000-000000000002','sales'),
  ('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000003','inventory');

INSERT INTO public.products(id, company_id, name)
VALUES
  ('0ed6991c-cfe3-411e-a264-86ac42add7c0','01350a71-0a93-44cf-b6c9-9bd547c0077a','Yellow Plywood'),
  ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Other company product');

\ir ../supabase/candidates/20261107071000_seed_blackrock_opening_stock_61_yellow_plywood.sql

DO $$
DECLARE
  v_qty numeric;
  v_cost numeric;
  v_count integer;
BEGIN
  SELECT count(*), max(quantity), max(unit_cost)
    INTO v_count, v_qty, v_cost
    FROM public.stock_movements
   WHERE reference_type = 'opening_balance_import'
     AND reference_id IS NULL;
  IF v_count <> 1 OR v_qty <> 61 OR v_cost <> 4300 THEN
    RAISE EXCEPTION 'Opening-stock import assertion failed';
  END IF;
END $$;

INSERT INTO public.purchase_documents(id,company_id,document_type,document_number,status)
VALUES
  ('50000000-0000-0000-0000-000000000001','01350a71-0a93-44cf-b6c9-9bd547c0077a','supplier_invoice','PI-TEST-1','approved'),
  ('50000000-0000-0000-0000-000000000002','01350a71-0a93-44cf-b6c9-9bd547c0077a','supplier_invoice','PI-TEST-2','approved'),
  ('50000000-0000-0000-0000-000000000003','01350a71-0a93-44cf-b6c9-9bd547c0077a','supplier_invoice','PI-TEST-3','approved'),
  ('50000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','supplier_invoice','PI-OTHER','approved');

INSERT INTO public.purchase_document_items(id,company_id,purchase_document_id,product_id,description,quantity,unit_cost)
VALUES
  ('60000000-0000-0000-0000-000000000001','01350a71-0a93-44cf-b6c9-9bd547c0077a','50000000-0000-0000-0000-000000000001','0ed6991c-cfe3-411e-a264-86ac42add7c0','Plywood',10,50),
  ('60000000-0000-0000-0000-000000000002','01350a71-0a93-44cf-b6c9-9bd547c0077a','50000000-0000-0000-0000-000000000002','0ed6991c-cfe3-411e-a264-86ac42add7c0','Zero-cost line',10,0),
  ('60000000-0000-0000-0000-000000000003','01350a71-0a93-44cf-b6c9-9bd547c0077a','50000000-0000-0000-0000-000000000003','0ed6991c-cfe3-411e-a264-86ac42add7c0','Permission test',10,50),
  ('60000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000002','Other company line',10,50);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000001',false);

DO $$
DECLARE
  v_result jsonb;
  v_received numeric;
  v_movements integer;
  v_status text;
BEGIN
  v_result := public.receive_purchase_document(
    '50000000-0000-0000-0000-000000000001',
    '[{"item_id":"60000000-0000-0000-0000-000000000001","quantity_received":4}]'::jsonb
  );
  SELECT received_quantity INTO v_received
    FROM public.purchase_document_items
   WHERE id='60000000-0000-0000-0000-000000000001';
  SELECT count(*) INTO v_movements
    FROM public.stock_movements
   WHERE reference_id='50000000-0000-0000-0000-000000000001';
  SELECT status INTO v_status
    FROM public.purchase_documents
   WHERE id='50000000-0000-0000-0000-000000000001';
  IF v_received <> 4 OR v_movements <> 1 OR v_status <> 'partially_received'
     OR v_result->>'status' <> 'partially_received' THEN
    RAISE EXCEPTION 'Partial receipt assertion failed';
  END IF;

  BEGIN
    PERFORM public.receive_purchase_document(
      '50000000-0000-0000-0000-000000000001',
      '[{"item_id":"60000000-0000-0000-0000-000000000001","quantity_received":7}]'::jsonb
    );
    RAISE EXCEPTION 'Expected over-receipt rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected over-receipt rejection' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.receive_purchase_document(
      '50000000-0000-0000-0000-000000000001',
      '[{"item_id":"60000000-0000-0000-0000-000000000001","quantity_received":1},{"item_id":"60000000-0000-0000-0000-000000000001","quantity_received":1}]'::jsonb
    );
    RAISE EXCEPTION 'Expected duplicate-item rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected duplicate-item rejection' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.receive_purchase_document(
      '50000000-0000-0000-0000-000000000002',
      '[{"item_id":"60000000-0000-0000-0000-000000000002","quantity_received":1}]'::jsonb
    );
    RAISE EXCEPTION 'Expected zero-cost rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected zero-cost rejection' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.receive_purchase_document(
      '50000000-0000-0000-0000-000000000001',
      '[{"item_id":"69999999-0000-0000-0000-000000000001","quantity_received":1}]'::jsonb
    );
    RAISE EXCEPTION 'Expected foreign/unknown line rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected foreign/unknown line rejection' THEN RAISE; END IF;
  END;

  PERFORM public.receive_purchase_document(
    '50000000-0000-0000-0000-000000000001',
    '[{"item_id":"60000000-0000-0000-0000-000000000001","quantity_received":6}]'::jsonb
  );
  SELECT received_quantity INTO v_received
    FROM public.purchase_document_items
   WHERE id='60000000-0000-0000-0000-000000000001';
  SELECT count(*) INTO v_movements
    FROM public.stock_movements
   WHERE reference_id='50000000-0000-0000-0000-000000000001';
  SELECT status INTO v_status
    FROM public.purchase_documents
   WHERE id='50000000-0000-0000-0000-000000000001';
  IF v_received <> 10 OR v_movements <> 2 OR v_status <> 'received' THEN
    RAISE EXCEPTION 'Final receipt assertion failed';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000002',false);
DO $$
BEGIN
  BEGIN
    PERFORM public.receive_purchase_document(
      '50000000-0000-0000-0000-000000000003',
      '[{"item_id":"60000000-0000-0000-0000-000000000003","quantity_received":1}]'::jsonb
    );
    RAISE EXCEPTION 'Expected non-inventory role rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected non-inventory role rejection' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
DO $$
BEGIN
  BEGIN
    PERFORM public.receive_purchase_document(
      '50000000-0000-0000-0000-000000000001',
      '[{"item_id":"60000000-0000-0000-0000-000000000001","quantity_received":1}]'::jsonb
    );
    RAISE EXCEPTION 'Expected cross-company membership rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Expected cross-company membership rejection' THEN RAISE; END IF;
  END;
END $$;

RESET ROLE;
SELECT 'PASS: purchase receiving partial/final receipts, positive cost, duplicate/overreceipt rejection, role and company isolation.' AS result;
