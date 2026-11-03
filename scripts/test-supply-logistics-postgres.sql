\set ON_ERROR_STOP on
\! createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" supply_logistics_isolated
\connect supply_logistics_isolated

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN EXECUTE 'CREATE ROLE anon NOLOGIN'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN EXECUTE 'CREATE ROLE authenticated NOLOGIN'; END IF;
END
$roles$;
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE TABLE public.companies (id uuid PRIMARY KEY, code text NOT NULL, name text NOT NULL, is_active boolean NOT NULL);
CREATE TABLE public.company_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  role text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);

CREATE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE
AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

CREATE FUNCTION private.has_company_membership(p_company_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT (SELECT auth.uid()) IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.company_memberships m
    WHERE m.company_id=p_company_id AND m.user_id=(SELECT auth.uid()) AND m.is_active=true
  )
$$;
GRANT USAGE ON SCHEMA auth, private TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_company_membership(uuid) TO authenticated;

GRANT SELECT ON public.companies, public.company_memberships TO authenticated;

INSERT INTO public.companies(id,code,name,is_active) VALUES
('01350a71-0a93-44cf-b6c9-9bd547c0077a','BLACKROCK','BlackRock Investment PLC',true),
('e326f16c-7a76-4bf2-8322-fec959266992','PRIME','Prime Investment Group',true);
INSERT INTO auth.users(id) VALUES
('11111111-1111-4111-8111-111111111111'),
('22222222-2222-4222-8222-222222222222'),
('33333333-3333-4333-8333-333333333333');
INSERT INTO public.company_memberships(company_id,user_id,role,is_active) VALUES
('e326f16c-7a76-4bf2-8322-fec959266992','11111111-1111-4111-8111-111111111111','inventory',true),
('01350a71-0a93-44cf-b6c9-9bd547c0077a','22222222-2222-4222-8222-222222222222','inventory',true),
('e326f16c-7a76-4bf2-8322-fec959266992','33333333-3333-4333-8333-333333333333','sales',true);

\ir ../supabase/migrations/20261031082508_add_company_scoped_supply_logistics_foundation.sql
\ir ../supabase/migrations/20261031083706_index_supply_logistics_created_by.sql
\ir ../supabase/migrations/20261031084536_add_supply_shipment_purchasing_entity.sql

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
INSERT INTO public.supply_shipments(company_id,shipment_no,factory_name,planned_quantity,status)
VALUES ('e326f16c-7a76-4bf2-8322-fec959266992','SH-PRIME-001','Test Factory',120,'Planned');

DO $$
BEGIN
  IF (SELECT count(*) FROM public.supply_shipments) <> 1 THEN
    RAISE EXCEPTION 'PRIME inventory member should read its own shipment.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.supply_shipments WHERE company_id='01350a71-0a93-44cf-b6c9-9bd547c0077a') THEN
    RAISE EXCEPTION 'PRIME inventory member must not read BLACKROCK shipment rows.';
  END IF;
  BEGIN
    INSERT INTO public.supply_shipments(company_id,shipment_no,factory_name,planned_quantity)
    VALUES ('01350a71-0a93-44cf-b6c9-9bd547c0077a','SH-CROSS-001','Cross Company Factory',5);
    RAISE EXCEPTION 'Cross-company shipment insert unexpectedly succeeded.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;

UPDATE public.supply_shipments SET status='Ordered' WHERE shipment_no='SH-PRIME-001';
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
INSERT INTO public.supply_shipments(company_id,shipment_no,factory_name,purchasing_entity,planned_quantity,status)
VALUES ('01350a71-0a93-44cf-b6c9-9bd547c0077a','SH-BLACKROCK-BOKAN','Shared Coordination Factory','BOKAN Coordinated',15,'Planned');
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
INSERT INTO public.delivery_orders(company_id,delivery_no,customer_name,required_quantity,allocated_quantity,delivery_status)
VALUES ('e326f16c-7a76-4bf2-8322-fec959266992','DO-PRIME-001','Test Customer',50,20,'Reserved');

DO $$
BEGIN
  BEGIN
    INSERT INTO public.supply_shipments(company_id,shipment_no,factory_name,planned_quantity)
    VALUES ('e326f16c-7a76-4bf2-8322-fec959266992','SH-SALES-DENIED','Sales User Factory',5);
    RAISE EXCEPTION 'Sales-only member unexpectedly created an inbound shipment.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    INSERT INTO public.delivery_orders(company_id,delivery_no,customer_name,required_quantity,allocated_quantity)
    VALUES ('e326f16c-7a76-4bf2-8322-fec959266992','DO-INVALID','Invalid Allocation',10,11);
    RAISE EXCEPTION 'Delivery allocation above required quantity unexpectedly succeeded.';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
  UPDATE public.delivery_orders SET delivery_status='Delivered' WHERE delivery_no='DO-PRIME-001';
  IF FOUND THEN
    RAISE EXCEPTION 'Sales-only member unexpectedly updated delivery controls.';
  END IF;
END
$$;

RESET ROLE;
DO $$
BEGIN
  IF has_table_privilege('anon','public.supply_shipments','SELECT') THEN
    RAISE EXCEPTION 'Anonymous role unexpectedly has shipment read access.';
  END IF;
  IF has_table_privilege('anon','public.delivery_orders','SELECT') THEN
    RAISE EXCEPTION 'Anonymous role unexpectedly has delivery read access.';
  END IF;
END
$$;


-- Operational cost register and allocation candidate: isolated integration test.
CREATE TABLE public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  category text NOT NULL,
  amount numeric(14,2) NOT NULL CHECK (amount >= 0),
  description text NOT NULL DEFAULT '',
  location text,
  paid_by text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE(company_id,id)
);
CREATE TABLE public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  name text NOT NULL,
  UNIQUE(company_id,id)
);
CREATE TABLE public.suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  name text NOT NULL,
  UNIQUE(company_id,id)
);
GRANT SELECT ON public.customers, public.products TO authenticated;
CREATE TABLE public.purchase_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  document_number text NOT NULL,
  UNIQUE(company_id,id)
);
CREATE TABLE public.sales_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  customer_id uuid,
  document_type text NOT NULL DEFAULT 'sales_order',
  document_number text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  document_date date NOT NULL DEFAULT current_date,
  due_date date,
  currency_code text NOT NULL DEFAULT 'ETB',
  subtotal numeric(16,2) NOT NULL DEFAULT 0,
  tax_total numeric(16,2) NOT NULL DEFAULT 0,
  discount_total numeric(16,2) NOT NULL DEFAULT 0,
  grand_total numeric(16,2) NOT NULL DEFAULT 0,
  notes text,
  created_by uuid REFERENCES auth.users(id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(company_id,id)
);
ALTER TABLE public.sales_documents
  ADD CONSTRAINT sales_documents_customer_company_fk
  FOREIGN KEY(company_id,customer_id) REFERENCES public.customers(company_id,id) ON DELETE RESTRICT;
CREATE TABLE public.sales_document_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL,
  document_id uuid NOT NULL,
  product_id uuid,
  description text NOT NULL,
  quantity numeric(14,3) NOT NULL,
  unit text NOT NULL,
  unit_price numeric(16,2) NOT NULL,
  tax_rate numeric(7,3) NOT NULL DEFAULT 0,
  line_subtotal numeric(16,2) NOT NULL,
  line_tax numeric(16,2) NOT NULL DEFAULT 0,
  line_total numeric(16,2) NOT NULL,
  FOREIGN KEY(company_id,document_id) REFERENCES public.sales_documents(company_id,id) ON DELETE CASCADE,
  FOREIGN KEY(company_id,product_id) REFERENCES public.products(company_id,id) ON DELETE RESTRICT
);
ALTER TABLE public.delivery_orders ADD COLUMN sales_document_id uuid;
ALTER TABLE public.sales_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY sales_documents_test_select ON public.sales_documents
FOR SELECT TO authenticated USING (private.has_company_membership(company_id));
CREATE POLICY sales_documents_test_insert ON public.sales_documents
FOR INSERT TO authenticated WITH CHECK (
  private.has_company_membership(company_id) AND EXISTS (
    SELECT 1 FROM public.company_memberships m
    WHERE m.company_id=sales_documents.company_id AND m.user_id=(select auth.uid())
      AND m.is_active AND m.role IN ('owner','admin','manager','sales','staff')
  )
);
ALTER TABLE public.sales_document_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY sales_document_items_test_select ON public.sales_document_items
FOR SELECT TO authenticated USING (private.has_company_membership(company_id));
CREATE POLICY sales_document_items_test_insert ON public.sales_document_items
FOR INSERT TO authenticated WITH CHECK (
  private.has_company_membership(company_id) AND EXISTS (
    SELECT 1 FROM public.company_memberships m
    WHERE m.company_id=sales_document_items.company_id AND m.user_id=(select auth.uid())
      AND m.is_active AND m.role IN ('owner','admin','manager','sales','staff')
  )
);
GRANT SELECT, INSERT ON public.sales_documents TO authenticated;
GRANT SELECT, INSERT ON public.sales_document_items TO authenticated;

\ir ../supabase/candidates/blackrock_sales_orders.sql

CREATE TABLE public.expense_test_ids (
  company_code text PRIMARY KEY,
  expense_id uuid NOT NULL,
  product_id uuid NOT NULL,
  purchase_id uuid NOT NULL,
  sales_id uuid NOT NULL,
  shipment_id uuid NOT NULL,
  delivery_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  supplier_id uuid NOT NULL
);

INSERT INTO auth.users(id) VALUES ('44444444-4444-4444-8444-444444444444');
INSERT INTO public.company_memberships(company_id,user_id,role,is_active)
VALUES ('e326f16c-7a76-4bf2-8322-fec959266992','44444444-4444-4444-8444-444444444444','manager',true);

INSERT INTO public.products(company_id,name)
SELECT c.id, c.code || ' Test Product' FROM public.companies c;
INSERT INTO public.customers(company_id,name)
SELECT c.id, c.code || ' Test Customer' FROM public.companies c;
INSERT INTO public.suppliers(company_id,name)
SELECT c.id, c.code || ' Test Supplier' FROM public.companies c;
INSERT INTO public.purchase_documents(company_id,document_number)
SELECT c.id, c.code || '-PO-001' FROM public.companies c;
INSERT INTO public.sales_documents(company_id,customer_id,document_number)
SELECT c.id,cu.id,c.code || '-SO-001'
FROM public.companies c JOIN public.customers cu ON cu.company_id=c.id;
INSERT INTO public.expenses(company_id,category,amount,description,created_by)
SELECT c.id,'direct cost',100,'CI operational expense',u.id
FROM public.companies c
JOIN auth.users u ON u.id = CASE c.code WHEN 'PRIME' THEN '11111111-1111-4111-8111-111111111111'::uuid ELSE '22222222-2222-4222-8222-222222222222'::uuid END;

INSERT INTO public.delivery_orders(company_id,delivery_no,customer_name,required_quantity,allocated_quantity,delivery_status)
VALUES ('01350a71-0a93-44cf-b6c9-9bd547c0077a','DO-BLACKROCK-001','BlackRock Test Customer',10,0,'Stock Check');
INSERT INTO public.expense_test_ids(company_code,expense_id,product_id,purchase_id,sales_id,shipment_id,delivery_id,customer_id,supplier_id)
SELECT c.code,e.id,p.id,po.id,so.id,sh.id,d.id,cu.id,su.id
FROM public.companies c
JOIN public.expenses e ON e.company_id=c.id
JOIN public.products p ON p.company_id=c.id
JOIN public.purchase_documents po ON po.company_id=c.id
JOIN public.sales_documents so ON so.company_id=c.id
JOIN public.supply_shipments sh ON sh.company_id=c.id
JOIN public.delivery_orders d ON d.company_id=c.id
JOIN public.customers cu ON cu.company_id=c.id
JOIN public.suppliers su ON su.company_id=c.id;
GRANT SELECT ON public.expense_test_ids TO authenticated;

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY expenses_test_select_member ON public.expenses
FOR SELECT TO authenticated USING (private.has_company_membership(company_id));
GRANT SELECT ON public.expenses TO authenticated;

\ir ../supabase/candidates/blackrock_operational_costs.sql

-- Delivery product links must reject cross-company catalogue items.
DO $delivery_product_tenant$
DECLARE
  v_blackrock_product uuid;
  v_denied boolean := false;
BEGIN
  SELECT product_id INTO v_blackrock_product
  FROM public.expense_test_ids WHERE company_code='BLACKROCK';
  BEGIN
    UPDATE public.delivery_orders
    SET product_id=v_blackrock_product
    WHERE delivery_no='DO-PRIME-001';
  EXCEPTION WHEN foreign_key_violation THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'PRIME delivery control accepted a BLACKROCK product';
  END IF;
END
$delivery_product_tenant$;

-- Sales order creation and operational stage changes use company-scoped persistence.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
DO $sales_order_test$
DECLARE
  v_customer uuid;
  v_product uuid;
  v_order public.sales_documents;
  v_denied boolean := false;
BEGIN
  SELECT customer_id INTO v_customer FROM public.expense_test_ids WHERE company_code='PRIME';
  SELECT product_id INTO v_product FROM public.expense_test_ids WHERE company_code='PRIME';
  v_order := public.create_blackrock_operational_sales_order(
    'e326f16c-7a76-4bf2-8322-fec959266992',v_customer,'CI Operational Plywood',12,'pcs',950,v_product,current_date+3,'CI order persistence'
  );
  IF v_order.document_type<>'sales_order' OR v_order.operational_stage<>'customer_order'
     OR v_order.grand_total<>11400 OR v_order.status<>'submitted' THEN
    RAISE EXCEPTION 'Sales order did not persist expected initial document fields';
  END IF;
  IF (SELECT count(*) FROM public.sales_document_items WHERE document_id=v_order.id)<>1 THEN
    RAISE EXCEPTION 'Sales order must persist its line item';
  END IF;
  PERFORM public.update_blackrock_operational_sales_order_stage(
    'e326f16c-7a76-4bf2-8322-fec959266992',v_order.id,'stock_reserved'
  );
  IF (SELECT operational_stage FROM public.sales_documents WHERE id=v_order.id)<>'stock_reserved' THEN
    RAISE EXCEPTION 'Sales order operational stage was not updated';
  END IF;
  v_denied := false;
  BEGIN
    PERFORM public.update_blackrock_operational_sales_order_stage(
      'e326f16c-7a76-4bf2-8322-fec959266992',v_order.id,'not-a-stage'
    );
  EXCEPTION WHEN raise_exception THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Unsupported sales order stage was accepted'; END IF;
END
$sales_order_test$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
DO $sales_order_tenant$
DECLARE
  v_customer uuid;
  v_denied boolean := false;
BEGIN
  SELECT customer_id INTO v_customer FROM public.expense_test_ids WHERE company_code='PRIME';
  BEGIN
    PERFORM public.create_blackrock_operational_sales_order(
      'e326f16c-7a76-4bf2-8322-fec959266992',v_customer,'Cross-company order',1,'pcs',1,NULL,NULL,NULL
    );
  EXCEPTION WHEN raise_exception THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'BLACKROCK user created a PRIME sales order'; END IF;
END
$sales_order_tenant$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
DO $allocation_role_test$
DECLARE v_denied boolean := false;
BEGIN
  BEGIN
    INSERT INTO public.expense_allocations(company_id,expense_id,product_id,allocated_amount,created_by)
    SELECT c.id,t.expense_id,t.product_id,1,(select auth.uid())
    FROM public.expense_test_ids t JOIN public.companies c ON c.code=t.company_code
    WHERE t.company_code='PRIME';
  EXCEPTION WHEN insufficient_privilege THEN v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'Non-manager allocation insert was not rejected';
  END IF;
END
$allocation_role_test$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',false);
INSERT INTO public.expense_allocations(company_id,expense_id,purchase_document_id,allocated_amount,allocation_method,created_by)
SELECT c.id,t.expense_id,t.purchase_id,40,'manual',(select auth.uid())
FROM public.expense_test_ids t JOIN public.companies c ON c.code=t.company_code
WHERE t.company_code='PRIME';
INSERT INTO public.expense_allocations(company_id,expense_id,shipment_id,allocated_amount,allocation_method,created_by)
SELECT c.id,t.expense_id,t.shipment_id,50,'quantity',(select auth.uid())
FROM public.expense_test_ids t JOIN public.companies c ON c.code=t.company_code
WHERE t.company_code='PRIME';

DO $cost_test$
DECLARE v_denied boolean := false; v_visible integer; v_unallocated numeric;
BEGIN
  BEGIN
    INSERT INTO public.expense_allocations(company_id,expense_id,product_id,allocated_amount,created_by)
    SELECT c.id,t.expense_id,t.product_id,20,(select auth.uid())
    FROM public.expense_test_ids t JOIN public.companies c ON c.code=t.company_code
    WHERE t.company_code='PRIME';
  EXCEPTION WHEN raise_exception THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Allocation above source expense amount was accepted'; END IF;

  SELECT unallocated_amount INTO v_unallocated
  FROM public.expense_allocation_summary s
  JOIN public.expense_test_ids t ON t.expense_id=s.expense_id
  WHERE t.company_code='PRIME';
  IF v_unallocated <> 10 THEN RAISE EXCEPTION 'Expected ETB 10 unallocated, got %',v_unallocated; END IF;

  v_denied := false;
  BEGIN
    INSERT INTO public.expense_allocations(company_id,expense_id,product_id,allocated_amount,created_by)
    SELECT c.id,prime.expense_id,blackrock.product_id,1,(select auth.uid())
    FROM public.expense_test_ids prime
    JOIN public.expense_test_ids blackrock ON blackrock.company_code='BLACKROCK'
    JOIN public.companies c ON c.code='PRIME'
    WHERE prime.company_code='PRIME';
  EXCEPTION WHEN foreign_key_violation THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Cross-company product allocation was accepted'; END IF;

  SELECT count(*) INTO v_visible FROM public.expense_allocation_summary;
  IF v_visible <> 1 THEN RAISE EXCEPTION 'PRIME user saw % cost summaries instead of 1',v_visible; END IF;
END
$cost_test$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
DO $tenant_test$
DECLARE v_visible integer;
BEGIN
  SELECT count(*) INTO v_visible FROM public.expense_allocation_summary;
  IF v_visible <> 1 THEN RAISE EXCEPTION 'BLACKROCK user saw % cost summaries instead of 1',v_visible; END IF;
  IF EXISTS (
    SELECT 1 FROM public.expense_allocations a
    JOIN public.expense_test_ids t ON t.expense_id=a.expense_id
    WHERE t.company_code='PRIME'
  ) THEN RAISE EXCEPTION 'BLACKROCK user read PRIME cost allocations'; END IF;
END
$tenant_test$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',false);
UPDATE public.expense_allocations
SET allocation_note='Reviewed by manager'
WHERE allocation_method='manual';
DO $audit_test$
BEGIN
  IF (SELECT count(*) FROM public.expense_allocation_events WHERE event_type='UPDATE') <> 1 THEN
    RAISE EXCEPTION 'Allocation update was not captured in audit history';
  END IF;
END
$audit_test$;
RESET ROLE;

DO $privilege_test$
BEGIN
  IF has_table_privilege('authenticated','public.expenses','TRUNCATE')
     OR has_table_privilege('authenticated','public.expenses','REFERENCES')
     OR has_table_privilege('authenticated','public.expenses','TRIGGER') THEN
    RAISE EXCEPTION 'Authenticated role retains non-DML expense privileges';
  END IF;
  IF has_table_privilege('authenticated','public.products','TRUNCATE')
     OR has_table_privilege('authenticated','public.products','REFERENCES')
     OR has_table_privilege('authenticated','public.products','TRIGGER') THEN
    RAISE EXCEPTION 'Authenticated role retains non-DML product catalogue privileges';
  END IF;
  IF has_table_privilege('anon','public.expense_allocations','SELECT') THEN
    RAISE EXCEPTION 'Anonymous role can read expense allocations';
  END IF;
END
$privilege_test$;

\connect live_company_test
DROP DATABASE supply_logistics_isolated WITH (FORCE);
