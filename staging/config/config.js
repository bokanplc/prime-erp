// BOKAN ERP staging configuration template.
// Intentionally disabled: do not enable production until database schema,
// authentication, row-level security, and smoke tests have been completed.
// Never put a Supabase service-role/secret key in this browser file.
window.BOKAN_CONFIG = {
  // Only the dedicated staging preview may use local sample data and demo entry.
  DEMO_REVIEW_MODE: true,
  // Optional exact Supabase Auth redirect URL; blank uses the current app origin.
  AUTH_REDIRECT_URL: '',
  PRODUCTION_MODE: false,
  // V7 uses Supabase Auth only; never start the retired Cloudflare /api login/store adapter.
  V7_SUPABASE_AUTH_ONLY: true,
  FULL_ERP_DATA_READY: false,
  // No production modules are approved yet. Add a tab only after its database, RLS, persistence and browser tests pass and source allowlist is updated.
  ENABLED_PRODUCTION_TABS: [],
  SUPABASE_URL: "",
  SUPABASE_ANON_KEY: ""
};
