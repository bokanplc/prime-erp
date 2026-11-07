-- Candidate data migration: BlackRock's documented opening stock.
-- Source: 1Q_Report_BR_Prime_Clean_Corporate.xlsx, Daily_Data_Entry row 8.
-- 2026-07-01 | BlackRock | Yellow Plywood | 61 pcs | ETB 4,300/pc.
-- Total opening value: ETB 262,300.
-- This script is intentionally isolated under supabase/candidates and is not
-- applied automatically. It refuses to seed if any stock movement already
-- exists for this product, so it cannot double-count a later stock ledger.

DO $$
DECLARE
  v_company_id uuid;
  v_product_id uuid;
  v_company_count integer;
  v_product_count integer;
  v_existing public.stock_movements%rowtype;
BEGIN
  SELECT count(*), min(c.id::text)::uuid
    INTO v_company_count, v_company_id
    FROM public.companies c
   WHERE c.name = 'BlackRock Investment PLC';

  IF v_company_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one BlackRock Investment PLC company record';
  END IF;

  SELECT count(*), min(p.id::text)::uuid
    INTO v_product_count, v_product_id
    FROM public.products p
   WHERE p.company_id = v_company_id
     AND p.name = 'Yellow Plywood';

  IF v_product_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one BlackRock Yellow Plywood product mapping';
  END IF;

  SELECT *
    INTO v_existing
    FROM public.stock_movements
   WHERE company_id = v_company_id
     AND product_id = v_product_id
     AND movement_type = 'opening'
     AND reference_type = 'opening_balance_import'
     AND reference_id IS NULL
     AND movement_date = timestamptz '2026-07-01 00:00:00+03'
   FOR UPDATE;

  IF FOUND THEN
    IF v_existing.quantity <> 61 OR v_existing.unit_cost <> 4300 THEN
      RAISE EXCEPTION 'Opening-stock import exists with conflicting values';
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
    NULL,
    timestamptz '2026-07-01 00:00:00+03',
    'Opening stock per 1Q_Report_BR_Prime_Clean_Corporate.xlsx: 61 Yellow Plywood at ETB 4,300 each; total ETB 262,300.',
    NULL
  );
END;
$$;
