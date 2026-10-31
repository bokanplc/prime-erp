\set ON_ERROR_STOP on
BEGIN;

CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
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

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
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

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
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
  BEGIN
    UPDATE public.delivery_orders SET delivery_status='Delivered' WHERE delivery_no='DO-PRIME-001';
    RAISE EXCEPTION 'Sales-only member unexpectedly updated delivery controls.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
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

ROLLBACK;
