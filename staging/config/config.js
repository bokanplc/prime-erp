// BOKAN ERP staging configuration template.
// Intentionally disabled: do not enable production until database schema,
// authentication, row-level security, and smoke tests have been completed.
// Never put a Supabase service-role/secret key in this browser file.
window.BOKAN_CONFIG = {
  PRODUCTION_MODE: false,
  FULL_ERP_DATA_READY: false,
  // No production modules are approved yet. Add a tab only after its database, RLS, persistence and browser tests pass and source allowlist is updated.
  ENABLED_PRODUCTION_TABS: [],
  SUPABASE_URL: "",
  SUPABASE_ANON_KEY: ""
};
