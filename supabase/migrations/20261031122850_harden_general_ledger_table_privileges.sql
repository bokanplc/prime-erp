-- General Ledger is read-only through the Data API for signed-in users.
-- All ledger mutations must use validated, company-scoped RPC workflows.
revoke all privileges on table public.ledger_accounts, public.fiscal_periods, public.journal_entries, public.journal_lines from anon;
revoke insert, update, delete, truncate, references, trigger on table public.ledger_accounts, public.fiscal_periods, public.journal_entries, public.journal_lines from authenticated;
grant select on table public.ledger_accounts, public.fiscal_periods, public.journal_entries, public.journal_lines to authenticated;
