create index if not exists journal_entries_created_by_idx on public.journal_entries (created_by);
create index if not exists journal_entries_updated_by_idx on public.journal_entries (updated_by);
create index if not exists journal_user_access_created_by_idx on public.journal_user_access (created_by);