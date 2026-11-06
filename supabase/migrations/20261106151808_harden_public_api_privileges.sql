-- Harden browser-role privileges for the public Data API.
-- Preserve existing authenticated DML grants; RLS continues to scope rows.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
  ON ALL TABLES IN SCHEMA public FROM authenticated;

-- Future application objects must receive explicit grants rather than inheriting
-- broad browser access from the migration owner.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM anon, authenticated;

-- Restrict callable public functions to the explicitly used application RPCs.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bokan_save_company_proforma_settings(text, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.bokan_save_proforma(text, uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.bokan_reassign_customer_owner(uuid, uuid, uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_journal_entry(uuid, text, date, text, text, jsonb, text, uuid)
  TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;
