// BOKAN ERP staging configuration template.
// Intentionally disabled: do not enable production until database schema,
// authentication, row-level security, and smoke tests have been completed.
// Never put a Supabase service-role/secret key in this browser file.
window.BOKAN_CONFIG = {
  PRODUCTION_MODE: false,
  FULL_ERP_DATA_READY: false,
  SUPABASE_URL: "",
  SUPABASE_ANON_KEY: ""
};
