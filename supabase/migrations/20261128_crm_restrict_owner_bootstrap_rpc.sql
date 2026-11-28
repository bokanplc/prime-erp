-- Restrict one-time first-owner initialization RPC to signed-in users only.
REVOKE ALL ON FUNCTION public.crm_initialize_first_owner(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.crm_initialize_first_owner(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.crm_initialize_first_owner(text) TO authenticated;
