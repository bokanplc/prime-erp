# BOKAN Daily Journal

Standalone daily transaction-entry application. It uses the BOKAN ERP V7 Supabase project but stores journal data in dedicated `journal_entries` and `journal_user_access` tables. It does not write to ERP sales, purchasing, stock, accounting, or CRM tables.

## Behavior
- Staff sign in with individual Supabase Auth accounts.
- Admin can invite employees as `data_entry` or `viewer`.
- Submitted entries are permanently stored in Supabase.
- The same-day working list is displayed only before 18:00 Africa/Addis_Ababa.
- Data-entry users can update only records created on the current Addis Ababa business day before 18:00.
- Admin can update historical records.
- At 18:00, the temporary list is hidden; no permanent row is deleted.
- CSV export can be opened by Excel or imported into Google Sheets.

## Deploy
This directory is configured as the root directory of a separate Vercel project. No build command is required; `index.html` is static.

## Supabase
The SQL migration is in `supabase/migrations`. The frontend uses only the Supabase publishable key. Never put a service-role key in browser code. The `journal-invite-user` Edge Function uses the platform-provided service-role secret on the server.
