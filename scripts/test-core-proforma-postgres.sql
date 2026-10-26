\set ON_ERROR_STOP on

-- Disposable CI-only Supabase Auth shim. This file must never be run against the
-- real Supabase project; CI runs it inside a fresh PostgreSQL service container.
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    EXECUTE 'CREATE ROLE anon NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    EXECUTE 'CREATE ROLE authenticated NOLOGIN';
  END IF;
END
$roles$;

CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;

-- Apply only to the ephemeral CI database.
\i supabase/candidates/core_proforma_mvp.sql

INSERT INTO auth.users(id) VALUES
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222'),
  ('33333333-3333-4333-8333-333333333333'),
  ('44444444-4444-4444-8444-444444444444'),
  ('55555555-5555-4555-8555-555555555555'),
  ('66666666-6666-4666-8666-666666666666');

INSERT INTO public.profiles(id, full_name, role, department, company_code, active, terminated_at)
VALUES
  ('11111111-1111-4111-8111-111111111111', 'CI PRIME Sales', 'sales', 'Sales', 'PRIME', true, NULL),
  ('22222222-2222-4222-8222-222222222222', 'CI BlackRock Sales', 'sales', 'Sales', 'BLACKROCK', true, NULL),
  ('33333333-3333-4333-8333-333333333333', 'CI Inactive Sales', 'sales', 'Sales', 'PRIME', false, NULL),
  ('44444444-4444-4444-8444-444444444444', 'CI Terminated Sales', 'sales', 'Sales', 'PRIME', true, now()),
  ('55555555-5555-4555-8555-555555555555', 'CI PRIME Accounting', 'accounting', 'Accounting', 'PRIME', true, NULL),
  ('66666666-6666-4666-8666-666666666666', 'CI PRIME Sales Other', 'sales', 'Sales', 'PRIME', true, NULL);

INSERT INTO public.company_bank_accounts(company_code, bank_name, account_number, account_purpose, display_order, active)
VALUES
  ('PRIME', 'CI Test Bank', 'CI-123456', 'Settlement', 1, true),
  ('PRIME', 'Inactive Test Bank', 'CI-999999', 'Inactive', 2, false);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false);

DO $test$
DECLARE
  v_payload jsonb;
  v_first public.proformas;
  v_revision public.proformas;
  v_next public.proformas;
  v_blackrock public.proformas;
  v_visible integer := 0;
  v_denied boolean := false;
  v_invalid boolean := false;
  v_invalid_type boolean := false;
  v_invalid_settings boolean := false;
  v_invalid_text boolean := false;
BEGIN
  v_payload := jsonb_build_object(
    'customer', 'Acme Corporation',
    'tin', '123456789',
    'address', 'Test Address',
    'phone', '0911000000',
    'contactPerson', 'CI Test',
    'date', '2026-10-23',
    'vatPct', 15,
    'discountPct', 10,
    'delivery', '2-3 business days',
    'notes', 'CI-only smoke test',
    'withholdingEnabled', true,
    'withholdingRate', 3,
    'withholdingThreshold', 10000,
    'items', jsonb_build_array(jsonb_build_object(
      'description', 'Test item', 'spec', 'Standard', 'qty', 1, 'unit_price', 11500
    )),
    'terms', jsonb_build_array('Payment', 'Delivery'),
    'companyTinSnapshot', 'CLIENT-SPOOF-TIN',
    'banks', jsonb_build_array(jsonb_build_object('bank_name','Client Spoof Bank','account_number','SPOOF'))
  );

  v_first := public.bokan_save_proforma('PRIME', NULL, v_payload);
  INSERT INTO public.custom_terms(company_code, category, label, created_by)
  VALUES ('PRIME','payment','CI PRIME payment term',(select auth.uid()));
  IF v_first.proforma_no <> 'ACME1000' THEN
    RAISE EXCEPTION 'Expected first number ACME1000, got %', v_first.proforma_no;
  END IF;
  IF v_first.version_no <> 1 OR v_first.root_proforma_id IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected initial version/root metadata';
  END IF;
  IF v_first.subtotal_before_vat <> 10000
     OR v_first.vat_amount <> 1500
     OR v_first.discount_amount <> 1150
     OR v_first.grand_total <> 10350
     OR v_first.withholding_amount <> 310.50
     OR v_first.net_payable <> 10039.50 THEN
    RAISE EXCEPTION 'Unexpected computed totals: subtotal %, VAT %, discount %, gross %, withholding %, net %',
      v_first.subtotal_before_vat, v_first.vat_amount, v_first.discount_amount,
      v_first.grand_total, v_first.withholding_amount, v_first.net_payable;
  END IF;
  -- Direct RPC callers must not be able to disable or dilute the fixed withholding rule.
  v_denied := false;
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME', NULL, jsonb_set(v_payload, '{withholdingEnabled}', 'false'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Withholding is fixed at 3% on VAT-inclusive totals above ETB 10,000 and cannot be disabled or altered' THEN
      v_denied := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Direct RPC caller disabled withholding'; END IF;

  v_denied := false;
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME', NULL, jsonb_set(v_payload, '{withholdingRate}', '0'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Withholding is fixed at 3% on VAT-inclusive totals above ETB 10,000 and cannot be disabled or altered' THEN
      v_denied := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Direct RPC caller changed withholding rate'; END IF;

  v_denied := false;
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME', NULL, jsonb_set(v_payload, '{withholdingThreshold}', '100000'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Withholding is fixed at 3% on VAT-inclusive totals above ETB 10,000 and cannot be disabled or altered' THEN
      v_denied := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Direct RPC caller changed withholding threshold'; END IF;

  IF v_first.company_tin_snapshot <> '009588209'
     OR jsonb_typeof(v_first.bank_accounts_snapshot) <> 'array'
     OR jsonb_array_length(v_first.bank_accounts_snapshot) <> 1
     OR v_first.bank_accounts_snapshot->0->>'bank_name' <> 'CI Test Bank'
     OR v_first.bank_accounts_snapshot->0->>'account_number' <> 'CI-123456'
     OR v_first.bank_accounts_snapshot->0->>'purpose' <> 'Settlement' THEN
    RAISE EXCEPTION 'Issuer TIN/bank snapshots were not sourced only from active company records';
  END IF;

  v_revision := public.bokan_save_proforma('PRIME', v_first.id, v_payload);
  IF v_revision.proforma_no <> v_first.proforma_no
     OR v_revision.version_no <> 2
     OR v_revision.root_proforma_id <> v_first.id
     OR v_revision.document_action <> 'revision' THEN
    RAISE EXCEPTION 'Revision number/version/root linkage is incorrect';
  END IF;

  -- Another salesperson in the same company may read company records but cannot revise another user's proforma.
  PERFORM set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
  v_denied := false;
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME', v_first.id, v_payload);
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Not authorized to revise this proforma' THEN
      v_denied := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'Salesperson was allowed to revise another salesperson''s proforma';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

  v_next := public.bokan_save_proforma('PRIME', NULL, v_payload);
  IF v_next.proforma_no <> 'ACME1001' OR v_next.version_no <> 1 THEN
    RAISE EXCEPTION 'Second proforma number was not incremented atomically: %', v_next.proforma_no;
  END IF;

  -- Create one BlackRock row as a legitimate BlackRock user, then verify
  -- the PRIME session cannot read it through table-level SELECT/RLS.
  PERFORM set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  v_blackrock := public.bokan_save_proforma('BLACKROCK', NULL, v_payload);

  -- Custom terms must be isolated by company and cannot be inserted cross-tenant.
  SELECT count(*) INTO v_visible
    FROM public.custom_terms
   WHERE company_code = 'PRIME' AND label = 'CI PRIME payment term';
  IF v_visible <> 0 THEN
    RAISE EXCEPTION 'BlackRock user could read PRIME custom terms';
  END IF;
  v_denied := false;
  BEGIN
    INSERT INTO public.custom_terms(company_code, category, label, created_by)
    VALUES ('PRIME','payment','CI unauthorized cross-company term',(select auth.uid()));
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'BlackRock user could insert a PRIME custom term';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  SELECT count(*) INTO v_visible
    FROM public.proformas
   WHERE company_code = 'BLACKROCK';
  IF v_visible <> 0 THEN
    RAISE EXCEPTION 'PRIME user could read % BlackRock proforma rows', v_visible;
  END IF;

  -- BlackRock user must not save a PRIME proforma, even when calling the RPC directly.
  PERFORM set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  v_denied := false;
  BEGIN
    PERFORM public.bokan_save_proforma('PRIME', NULL, v_payload);
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Not authorized for this company' THEN
      v_denied := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'Cross-company proforma save was not denied';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  BEGIN
    PERFORM public.bokan_save_proforma(
      'PRIME', NULL,
      jsonb_set(v_payload, '{items,0,qty}', '-1'::jsonb)
    );
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE 'Every line item requires%' THEN
      v_invalid := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_invalid THEN
    RAISE EXCEPTION 'Invalid negative-quantity item was not rejected';
  END IF;

  -- String values that merely look numeric must not be cast into financial inputs.
  BEGIN
    PERFORM public.bokan_save_proforma(
      'PRIME', NULL,
      jsonb_set(v_payload, '{items,0,unit_price}', '"NaN"'::jsonb)
    );
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Line items must contain objects with a text description and numeric quantity/unit price' THEN
      v_invalid_type := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_invalid_type THEN
    RAISE EXCEPTION 'String-valued NaN unit price was not rejected by JSON type validation';
  END IF;

  BEGIN
    PERFORM public.bokan_save_proforma(
      'PRIME', NULL,
      jsonb_set(v_payload, '{vatPct}', '"NaN"'::jsonb)
    );
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Tax, discount, withholding and date fields have invalid JSON types' THEN
      v_invalid_settings := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_invalid_settings THEN
    RAISE EXCEPTION 'String-valued NaN VAT rate was not rejected by JSON type validation';
  END IF;

  BEGIN
    PERFORM public.bokan_save_proforma(
      'PRIME', NULL,
      jsonb_set(v_payload, '{customer}', '{"name":"spoof"}'::jsonb)
    );
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Customer and optional text fields must be JSON strings' THEN
      v_invalid_text := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_invalid_text THEN
    RAISE EXCEPTION 'Object-valued customer name was not rejected by text field validation';
  END IF;
END
$test$;

RESET ROLE;
SET ROLE authenticated;

DO $inactive_users$
DECLARE
  v_denied boolean := false;
  v_payload jsonb := jsonb_build_object(
    'customer','Inactive Test','tin','123456789','vatPct',15,'discountPct',0,
    'withholdingEnabled',true,'withholdingRate',3,'withholdingThreshold',10000,
    'items',jsonb_build_array(jsonb_build_object('description','Item','qty',1,'unit_price',100)),
    'terms',jsonb_build_array()
  );
  v_user uuid;
BEGIN
  FOREACH v_user IN ARRAY ARRAY[
    '33333333-3333-4333-8333-333333333333'::uuid,
    '44444444-4444-4444-8444-444444444444'::uuid
  ] LOOP
    PERFORM set_config('request.jwt.claim.sub', v_user::text, true);
    v_denied := false;
    BEGIN
      PERFORM public.bokan_save_proforma('PRIME', NULL, v_payload);
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'Not authorized for this company' THEN
        v_denied := true;
      ELSE
        RAISE;
      END IF;
    END;
    IF NOT v_denied THEN
      RAISE EXCEPTION 'Inactive or terminated profile % was allowed to save a proforma', v_user;
    END IF;
  END LOOP;
END
$inactive_users$;

RESET ROLE;
SET ROLE authenticated;

DO $company_settings$
DECLARE
  v_rows integer := 0;
  v_tin text;
BEGIN
  -- A sales user can read its company but cannot mutate issuer identity settings.
  PERFORM set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  UPDATE public.companies SET tin = 'UNAUTHORIZED-TIN' WHERE code = 'PRIME';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 0 THEN
    RAISE EXCEPTION 'Sales role unexpectedly updated issuer TIN';
  END IF;
  SELECT tin INTO v_tin FROM public.companies WHERE code = 'PRIME';
  IF v_tin <> '009588209' THEN
    RAISE EXCEPTION 'Unauthorized issuer TIN update changed the stored value: %', v_tin;
  END IF;

  -- Accounting may update the permitted issuer fields for its own company.
  PERFORM set_config('request.jwt.claim.sub', '55555555-5555-4555-8555-555555555555', true);
  UPDATE public.companies SET tin = 'CI-TEMP-TIN' WHERE code = 'PRIME';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'Accounting role could not update its own issuer TIN';
  END IF;
  UPDATE public.companies SET tin = '009588209' WHERE code = 'PRIME';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'Accounting role could not restore the issuer TIN after test';
  END IF;
END
$company_settings$;

RESET ROLE;

DO $privileges$
BEGIN
  IF has_function_privilege('anon', 'public.bokan_save_proforma(text,uuid,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute the proforma save RPC';
  END IF;
  IF has_table_privilege('anon', 'public.proformas', 'SELECT') THEN
    RAISE EXCEPTION 'anon must not select proformas';
  END IF;
  IF has_table_privilege('authenticated', 'public.proformas', 'INSERT') THEN
    RAISE EXCEPTION 'authenticated clients must not insert proformas directly; use the trusted RPC';
  END IF;
  IF has_table_privilege('authenticated', 'public.proformas', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.proformas', 'DELETE') THEN
    RAISE EXCEPTION 'authenticated clients must not directly update or delete proformas';
  END IF;
  IF has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.profiles', 'company_code', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.profiles', 'active', 'UPDATE') THEN
    RAISE EXCEPTION 'authenticated users must not edit protected profile authorization fields';
  END IF;
  IF has_column_privilege('authenticated', 'public.companies', 'code', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.companies', 'active', 'UPDATE') THEN
    RAISE EXCEPTION 'Authenticated users must not change company code or active state';
  END IF;
  IF has_table_privilege('authenticated', 'public.company_bank_accounts', 'INSERT')
     OR has_table_privilege('authenticated', 'public.company_bank_accounts', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.company_bank_accounts', 'DELETE') THEN
    RAISE EXCEPTION 'authenticated clients must not directly mutate company bank accounts';
  END IF;
  IF has_table_privilege('anon', 'public.custom_terms', 'SELECT')
     OR has_table_privilege('authenticated', 'public.custom_terms', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.custom_terms', 'DELETE') THEN
    RAISE EXCEPTION 'Custom terms must be private to authenticated users and append-only for clients';
  END IF;
  IF has_function_privilege('anon', 'private.bokan_save_proforma(text,uuid,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute the private proforma implementation';
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public.bokan_save_proforma(text,uuid,jsonb)'::regprocedure) THEN
    RAISE EXCEPTION 'Proforma save RPC must remain SECURITY INVOKER';
  END IF;
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'private.bokan_save_proforma(text,uuid,jsonb)'::regprocedure) THEN
    RAISE EXCEPTION 'Private implementation must be SECURITY DEFINER';
  END IF;
END
$privileges$;

SELECT 'PASS: disposable PostgreSQL proforma schema, RLS, totals, numbering, revisions, and grants.' AS result;
