-- Candidate hardening only. Do not apply until reviewed against the live migration source.
-- Preserve existing SELECT/INSERT/UPDATE/DELETE grants; remove only privileges that
-- normal browser workflows do not need and that are not protected by row-level
-- security (notably TRUNCATE).
begin;
revoke truncate, trigger, references
  on all tables in schema public
  from public, anon, authenticated;
commit;
