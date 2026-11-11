-- Test-only Supabase Auth stand-in for disposable PostgreSQL migration tests.
-- This file is never applied to a hosted Supabase project.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (
  id uuid primary key
);
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
