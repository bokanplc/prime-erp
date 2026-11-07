-- Restore the purchase receiving workflow in the live schema.
-- This is a forward migration candidate. It is intentionally not applied to
-- the live database until disposable-Postgres and authenticated-role tests pass.

CREATE OR REPLACE FUNCTION public.receive_purchase_document(
  p_purchase_document_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_doc public.purchase_documents%rowtype;
  v_item record;
  v_updated integer := 0;
  v_movement_count integer := 0;
  v_all_received boolean;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_purchase_document_id IS NULL
     OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Purchase document ID and at least one received item are required';
  END IF;

  SELECT *
    INTO v_doc
    FROM public.purchase_documents
   WHERE id = p_purchase_document_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase document not found';
  END IF;

  IF NOT (
    private.can_manage_company(v_doc.company_id)
    OR EXISTS (
      SELECT 1
        FROM public.company_memberships m
       WHERE m.company_id = v_doc.company_id
         AND m.user_id = (SELECT auth.uid())
         AND m.is_active
         AND m.role = 'inventory'
    )
  ) THEN
    RAISE EXCEPTION 'Inventory or company-management permission required';
  END IF;

  IF v_doc.document_type NOT IN ('purchase_order', 'supplier_invoice') THEN
    RAISE EXCEPTION 'This purchase document type cannot receive stock';
  END IF;

  IF v_doc.status NOT IN ('approved', 'partially_received') THEN
    RAISE EXCEPTION 'Only approved purchase documents can be received';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM jsonb_to_recordset(p_items)
           AS x(item_id uuid, quantity_received numeric)
     WHERE x.item_id IS NULL
        OR x.quantity_received IS NULL
        OR x.quantity_received <= 0
  ) THEN
    RAISE EXCEPTION 'Each received item needs a valid item ID and positive quantity';
  END IF;

  IF (
    SELECT count(*)
      FROM jsonb_to_recordset(p_items)
           AS x(item_id uuid, quantity_received numeric)
  ) <> (
    SELECT count(DISTINCT item_id)
      FROM jsonb_to_recordset(p_items)
           AS x(item_id uuid, quantity_received numeric)
  ) THEN
    RAISE EXCEPTION 'Duplicate item IDs are not allowed in one receipt';
  END IF;

  FOR v_item IN
    SELECT x.item_id,
           x.quantity_received,
           pi.product_id,
           pi.quantity,
           pi.received_quantity,
           pi.unit_cost,
           pi.description,
           pi.company_id
      FROM jsonb_to_recordset(p_items)
           AS x(item_id uuid, quantity_received numeric)
      JOIN public.purchase_document_items pi
        ON pi.id = x.item_id
       AND pi.purchase_document_id = p_purchase_document_id
     ORDER BY pi.product_id, pi.id
     FOR UPDATE OF pi
  LOOP
    IF v_item.company_id <> v_doc.company_id THEN
      RAISE EXCEPTION 'Purchase line company mismatch';
    END IF;

    IF v_item.product_id IS NULL THEN
      RAISE EXCEPTION 'Every received stock item must be linked to a product';
    END IF;

    IF v_item.unit_cost IS NULL OR v_item.unit_cost <= 0 THEN
      RAISE EXCEPTION 'A positive documented unit cost is required before receiving stock';
    END IF;

    IF v_item.received_quantity + v_item.quantity_received > v_item.quantity THEN
      RAISE EXCEPTION 'Received quantity exceeds ordered quantity for item %',
        v_item.description;
    END IF;

    PERFORM 1
      FROM public.products p
     WHERE p.id = v_item.product_id
       AND p.company_id = v_doc.company_id
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product is missing or belongs to another company';
    END IF;

    UPDATE public.purchase_document_items
       SET received_quantity = received_quantity + v_item.quantity_received
     WHERE id = v_item.item_id
       AND purchase_document_id = p_purchase_document_id;

    INSERT INTO public.stock_movements (
      company_id,
      product_id,
      movement_type,
      quantity,
      unit_cost,
      reference_type,
      reference_id,
      notes,
      created_by
    )
    VALUES (
      v_doc.company_id,
      v_item.product_id,
      'purchase_receipt',
      v_item.quantity_received,
      v_item.unit_cost,
      'purchase_document',
      p_purchase_document_id,
      'Receipt for ' || v_doc.document_number || ': ' || v_item.description,
      (SELECT auth.uid())
    );

    v_updated := v_updated + 1;
    v_movement_count := v_movement_count + 1;
  END LOOP;

  IF v_updated <> jsonb_array_length(p_items) THEN
    RAISE EXCEPTION 'One or more received items do not belong to this purchase document';
  END IF;

  SELECT bool_and(received_quantity >= quantity)
    INTO v_all_received
    FROM public.purchase_document_items
   WHERE purchase_document_id = p_purchase_document_id
     AND company_id = v_doc.company_id;

  IF v_all_received IS NULL THEN
    RAISE EXCEPTION 'Purchase document has no receivable line items';
  END IF;

  UPDATE public.purchase_documents
     SET status = CASE
                    WHEN v_all_received THEN 'received'
                    ELSE 'partially_received'
                  END,
         updated_at = now()
   WHERE id = p_purchase_document_id
     AND company_id = v_doc.company_id;

  RETURN jsonb_build_object(
    'purchase_document_id', p_purchase_document_id,
    'items_received', v_updated,
    'stock_movements_created', v_movement_count,
    'status', CASE
                WHEN v_all_received THEN 'received'
                ELSE 'partially_received'
              END
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.receive_purchase_document(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.receive_purchase_document(uuid, jsonb)
  TO authenticated;
