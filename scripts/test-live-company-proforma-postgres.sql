\set ON_ERROR_STOP on

-- Disposable PostgreSQL-only harness for the UUID-company candidate.
-- Never run this file against the connected/live Supabase project.

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN EXECUTE 'CREATE ROLE anon NOLOGIN'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN EXECUTE 'CREATE ROLE authenticated NOLOGIN'; END IF;
END
$roles$;

CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;

CREATE TABLE public.companies(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.company_memberships(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  role text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(company_id,user_id)
);
CREATE SCHEMA private;
CREATE OR REPLACE FUNCTION private.has_company_membership(p_company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT (SELECT auth.uid()) IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.company_memberships m
    WHERE m.company_id=p_company_id AND m.user_id=(SELECT auth.uid()) AND m.is_active
  )
$$;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_company_membership(uuid) TO authenticated;

INSERT INTO auth.users(id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333'),
 ('44444444-4444-4444-8444-444444444444');

INSERT INTO public.companies(id,code,name,is_active) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','PRIME','PRIME Investment Group',true),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','BLACKROCK','BlackRock Investment PLC',true);
INSERT INTO public.company_memberships(company_id,user_id,role,is_active) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','admin',true),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','admin',true),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333','sales',false),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444','viewer',true);

\i supabase/candidates/live_company_proforma.sql

INSERT INTO public.company_bank_accounts(company_id,company_code,bank_name,account_number,account_purpose,display_order,active)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','PRIME','CI Test Bank','CI-123456','Settlement',1,true);

-- Authenticated owner: create, verify server-side math and immutable revision.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
DO $test$
DECLARE
  v_first public.proformas;
  v_revision public.proformas;
  v_payload jsonb := jsonb_build_object(
    'customer','Acme Test Ltd','tin','TEST-TIN-001','address','Test Address','phone','555',
    'contactPerson','Test Contact','date','2026-10-27','vatPct',15,'discountPct',0,
    'items',jsonb_build_array(jsonb_build_object('description','Test product','spec','18mm','qty',2,'unit_price',5750)),
    'terms',jsonb_build_array('Delivery in 7 days')
  );
  v_visible integer;
  v_settings_tin text;
  v_denied boolean := false;
BEGIN
  PERFORM public.bokan_save_company_proforma_settings('PRIME',jsonb_build_object('tin','ISSUER-TEST-TIN','address','Test Issuer Address','phone','555-0100'));
  SELECT issuer_tin INTO v_settings_tin FROM public.company_proforma_settings WHERE company_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  IF v_settings_tin <> 'ISSUER-TEST-TIN' THEN RAISE EXCEPTION 'Issuer settings RPC failed'; END IF;
  v_first := public.bokan_save_proforma('PRIME',NULL,v_payload);
  IF v_first.proforma_no <> 'ACME1000' THEN RAISE EXCEPTION 'Unexpected number: %',v_first.proforma_no; END IF;
  IF v_first.subtotal_before_vat <> 10000 OR v_first.vat_amount <> 1500 OR v_first.grand_total <> 11500 THEN
    RAISE EXCEPTION 'Incorrect VAT-inclusive totals: subtotal %, VAT %, grand %',v_first.subtotal_before_vat,v_first.vat_amount,v_first.grand_total;
  END IF;
  IF v_first.withholding_amount <> 345 OR v_first.net_payable <> 11155 THEN
    RAISE EXCEPTION 'Incorrect withholding/net totals: withholding %, net %',v_first.withholding_amount,v_first.net_payable;
  END IF;
  IF jsonb_array_length(v_first.bank_accounts_snapshot) <> 1 THEN RAISE EXCEPTION 'Bank account snapshot missing'; END IF;
  IF v_first.company_tin_snapshot <> 'ISSUER-TEST-TIN' THEN RAISE EXCEPTION 'Issuer TIN snapshot missing'; END IF;
  v_revision := public.bokan_save_proforma('PRIME',v_first.id,v_payload || jsonb_build_object('discountPct',10));
  IF v_revision.id = v_first.id OR v_revision.version_no <> 2 OR v_revision.root_proforma_id <> v_first.id THEN
    RAISE EXCEPTION 'Revision did not preserve immutable lineage';
  END IF;
  SELECT count(*) INTO v_visible FROM public.proformas;
  IF v_visible <> 2 THEN RAISE EXCEPTION 'Expected two visible Proforma versions, got %',v_visible; END IF;
  BEGIN
    PERFORM public.bokan_save_company_proforma_settings('BLACKROCK',jsonb_build_object('tin','CROSS-COMPANY')); 
    RAISE EXCEPTION 'Cross-company settings update unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Cross-company settings update unexpectedly succeeded' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%Company administrator permission required%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.bokan_save_proforma('BLACKROCK',NULL,v_payload);
    RAISE EXCEPTION 'Cross-company save unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Cross-company save unexpectedly succeeded' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%Active authorized company membership required%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME',NULL,jsonb_build_object('customer','Invalid','tin','T','items',jsonb_build_array(jsonb_build_object('description','bad','qty',0,'unit_price',1))));
    RAISE EXCEPTION 'Invalid line item unexpectedly succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Invalid line item unexpectedly succeeded' THEN RAISE; END IF;
  END;
END
$test$;

-- Create a BlackRock-only record, then prove the PRIME session cannot read it.
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
DO $blackrock$
DECLARE v_row public.proformas;
BEGIN
  v_row := public.bokan_save_proforma('BLACKROCK',NULL,jsonb_build_object(
    'customer','BlackRock Test','tin','BR-TIN','vatPct',15,'discountPct',0,
    'items',jsonb_build_array(jsonb_build_object('description','Private company item','qty',1,'unit_price',500))
  ));
  IF v_row.company_code <> 'BLACKROCK' THEN RAISE EXCEPTION 'BlackRock row has wrong company'; END IF;
END
$blackrock$;

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
DO $scope$
DECLARE v_count integer; v_other integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.proformas;
  SELECT count(*) INTO v_other FROM public.proformas WHERE company_code='BLACKROCK';
  IF v_count <> 2 OR v_other <> 0 THEN RAISE EXCEPTION 'Cross-company read isolation failed: visible %, other-company %',v_count,v_other; END IF;
END
$scope$;

-- An authenticated database role without a real user ID must be denied.
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','',false);
DO $unauth$
DECLARE v_denied boolean := false;
BEGIN
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME',NULL,jsonb_build_object('customer','No User','tin','T','items',jsonb_build_array(jsonb_build_object('description','x','qty',1,'unit_price',1))));
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%Authentication required%' THEN RAISE; END IF;
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Unauthenticated save unexpectedly succeeded'; END IF;
END
$unauth$;

-- A non-member cannot read Proformas through RLS or write via the RPC.
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
DO $inactive$
DECLARE v_count integer; v_denied boolean := false;
BEGIN
  SELECT count(*) INTO v_count FROM public.proformas;
  IF v_count <> 0 THEN RAISE EXCEPTION 'Inactive member can read Proformas'; END IF;
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME',NULL,jsonb_build_object('customer','Blocked','tin','T','items',jsonb_build_array(jsonb_build_object('description','x','qty',1,'unit_price',1))));
  EXCEPTION WHEN OTHERS THEN v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Inactive member save unexpectedly succeeded'; END IF;
END
$inactive$;

-- Authenticated user without an allowed business role is denied writes.
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',false);
DO $role$
DECLARE v_denied boolean := false;
BEGIN
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME',NULL,jsonb_build_object('customer','Blocked','tin','T','items',jsonb_build_array(jsonb_build_object('description','x','qty',1,'unit_price',1))));
  EXCEPTION WHEN OTHERS THEN v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Unsupported role save unexpectedly succeeded'; END IF;
END
$role$;

RESET ROLE;
DO $privileges$
BEGIN
  IF has_table_privilege('authenticated','public.proformas','INSERT') THEN RAISE EXCEPTION 'Authenticated role has direct Proforma INSERT'; END IF;
  IF has_table_privilege('authenticated','public.proformas','UPDATE') THEN RAISE EXCEPTION 'Authenticated role has direct Proforma UPDATE'; END IF;
  IF has_table_privilege('authenticated','public.proformas','DELETE') THEN RAISE EXCEPTION 'Authenticated role has direct Proforma DELETE'; END IF;
END
$privileges$;

\echo PASS: UUID-company Proforma schema, RLS, atomic save, totals, revisions and role/company isolation
