-- Move SECURITY DEFINER implementations behind the non-exposed private schema.
-- Public API wrappers remain SECURITY INVOKER and preserve the existing RPC contract.
ALTER FUNCTION public.bokan_reassign_customer_owner(uuid, uuid, uuid, text)
  SET SCHEMA private;
ALTER FUNCTION public.post_journal_entry(uuid, text, date, text, text, jsonb, text, uuid)
  SET SCHEMA private;

CREATE OR REPLACE FUNCTION public.bokan_reassign_customer_owner(
  p_company_id uuid, p_customer_id uuid, p_new_owner_user_id uuid, p_reason text
)
RETURNS public.crm_customer_assignments
LANGUAGE sql
SET search_path TO ''
AS $function$
  SELECT private.bokan_reassign_customer_owner(
    p_company_id, p_customer_id, p_new_owner_user_id, p_reason
  );
$function$;

CREATE OR REPLACE FUNCTION public.post_journal_entry(
  p_company_id uuid, p_journal_number text, p_journal_date date,
  p_memo text, p_currency_code text, p_lines jsonb,
  p_source_type text DEFAULT NULL, p_source_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE sql
SET search_path TO ''
AS $function$
  SELECT private.post_journal_entry(
    p_company_id, p_journal_number, p_journal_date, p_memo,
    p_currency_code, p_lines, p_source_type, p_source_id
  );
$function$;

REVOKE ALL ON FUNCTION public.bokan_reassign_customer_owner(uuid, uuid, uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.post_journal_entry(uuid, text, date, text, text, jsonb, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bokan_reassign_customer_owner(uuid, uuid, uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_journal_entry(uuid, text, date, text, text, jsonb, text, uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION private.bokan_reassign_customer_owner(uuid, uuid, uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.post_journal_entry(uuid, text, date, text, text, jsonb, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.bokan_reassign_customer_owner(uuid, uuid, uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.post_journal_entry(uuid, text, date, text, text, jsonb, text, uuid)
  TO authenticated;
