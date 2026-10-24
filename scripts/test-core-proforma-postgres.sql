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
\i docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql

INSERT INTO auth.users(id) VALUES
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');

INSERT INTO public.profiles(id, full_name, role, department, company_code, active)
VALUES
  ('11111111-1111-4111-8111-111111111111', 'CI PRIME Sales', 'sales', 'Sales', 'PRIME', true),
  ('22222222-2222-4222-8222-222222222222', 'CI BlackRock Sales', 'sales', 'Sales', 'BLACKROCK', true);

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
  v_denied boolean := false;
  v_invalid boolean := false;
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
  IF v_first.proforma_no <> 'ACME1000' THEN
    RAISE EXCEPTION 'Expected first number ACME1000, got %', v_first.proforma_no;
  END IF;
  IF v_first.version_no <> 1 OR v_first.root_proforma_id IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected initial version/root metadata';
  END IF;
  IF v_first.subtotal_before_vat <> 9000
     OR v_first.vat_amount <> 1350
     OR v_first.discount_amount <> 1150
     OR v_first.grand_total <> 10350
     OR v_first.withholding_amount <> 310.50
     OR v_first.net_payable <> 10039.50 THEN
    RAISE EXCEPTION 'Unexpected computed totals: subtotal %, VAT %, discount %, gross %, withholding %, net %',
      v_first.subtotal_before_vat, v_first.vat_amount, v_first.discount_amount,
      v_first.grand_total, v_first.withholding_amount, v_first.net_payable;
  END IF;
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

  v_next := public.bokan_save_proforma('PRIME', NULL, v_payload);
  IF v_next.proforma_no <> 'ACME1001' OR v_next.version_no <> 1 THEN
    RAISE EXCEPTION 'Second proforma number was not incremented atomically: %', v_next.proforma_no;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
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
END
$test$;

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
