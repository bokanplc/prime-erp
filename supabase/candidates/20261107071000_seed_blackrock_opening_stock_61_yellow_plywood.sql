-- Candidate data migration: BlackRock's documented opening stock.
-- Source: 1Q_Report_BR_Prime_Clean_Corporate.xlsx, Daily_Data_Entry row 6.
-- 2026-07-01 | BlackRock | Yellow Plywood | 61 pcs | ETB 4,300/pc.
-- Total opening value: ETB 262,300.
-- This script is intentionally isolated under supabase/candidates and is not
-- applied automatically. It refuses to seed if any stock movement already
-- exists for this product, so it cannot double-count a later stock ledger.

DO $$
DECLARE
  v_company_id uuid := '01350a71-0a93-44cf-b6c9-9bd547c0077a';
  v_product_id uuid := '0ed6991c-cfe3-411e-a264-86ac42add7c0';
  v_reference_id uuid := 'f8b2e0f5-0c6f-4b8d-9c8d-202607010001';
  v_product_name text;
  v_existing public.stock_movements%rowtype;
BEGIN
  SELECT p.name
    INTO v_product_name
    FROM public.products p
   WHERE p.id = v_product_id
     AND p.company_id = v_company_id;

  IF NOT FOUND OR v_product_name <> 'Yellow Plywood' THEN
    RAISE EXCEPTION 'Expected BlackRock Yellow Plywood product mapping was not found';
  END IF;

  SELECT *
    INTO v_existing
    FROM public.stock_movements
   WHERE reference_type = 'opening_balance_import'
     AND reference_id = v_reference_id;

  IF FOUND THEN
    IF v_existing.company_id <> v_company_id
       OR v_existing.product_id <> v_product_id
       OR v_existing.movement_type <> 'opening'
       OR v_existing.quantity <> 61
       OR v_existing.unit_cost <> 4300
       OR v_existing.movement_date <> timestamptz '2026-07-01 00:00:00+03' THEN
      RAISE EXCEPTION 'Opening-stock import reference exists with conflicting values';
    END IF;
    RAISE NOTICE 'Opening stock already imported; no duplicate created';
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.stock_movements
     WHERE company_id = v_company_id
       AND product_id = v_product_id
  ) THEN
    RAISE EXCEPTION 'Stock movements already exist for Yellow Plywood; reconcile before seeding opening stock';
  END IF;

  INSERT INTO public.stock_movements (
    company_id,
    product_id,
    movement_type,
    quantity,
    unit_cost,
    reference_type,
    reference_id,
    movement_date,
    notes,
    created_by
  )
  VALUES (
    v_company_id,
    v_product_id,
    'opening',
    61,
    4300,
    'opening_balance_import',
    v_reference_id,
    timestamptz '2026-07-01 00:00:00+03',
    'Opening stock per 1Q_Report_BR_Prime_Clean_Corporate.xlsx: 61 Yellow Plywood at ETB 4,300 each; total ETB 262,300.',
    NULL
  );
END;
$$;
