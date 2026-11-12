-- BlackRock Investment PLC is the sole V7 tenant.
-- Add company contact details and replace any previously applied dual-company bootstrap.
begin;

alter table public.companies
  add column if not exists address text not null default '',
  add column if not exists phone text not null default '';

create or replace function private.bootstrap_initial_companies()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_invited_at timestamptz;
  actor_email_confirmed_at timestamptz;
  blackrock_company_id uuid;
begin
  if actor_id is null then
    raise exception 'Sign in before initializing the BlackRock workspace.' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bokan-erp-v7-first-owner-bootstrap', 0));

  select u.invited_at, u.email_confirmed_at
    into actor_invited_at, actor_email_confirmed_at
  from auth.users u
  where u.id = actor_id;

  if actor_invited_at is null or actor_email_confirmed_at is null then
    raise exception 'The first administrator must use a verified account invited by the Supabase project administrator.'
      using errcode = '42501';
  end if;

  if exists (select 1 from public.companies)
     or exists (select 1 from public.company_memberships) then
    raise exception 'Initial BlackRock workspace setup has already been completed.' using errcode = '55000';
  end if;

  insert into public.companies
    (legal_name, display_name, currency_code, vat_rate_bps, address, phone)
  values
    ('BlackRock Investment PLC', 'BlackRock Investment PLC', 'ETB', 1500,
     'Meskel Flower, Addis Ababa', '978 23 48 20')
  returning id into blackrock_company_id;

  insert into public.company_memberships (company_id, user_id, role, is_active)
  values (blackrock_company_id, actor_id, 'admin', true);

  return blackrock_company_id;
end;
$$;

revoke all on function private.bootstrap_initial_companies() from public, anon, authenticated;
grant execute on function private.bootstrap_initial_companies() to authenticated;

create or replace function public.bootstrap_initial_companies()
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.bootstrap_initial_companies();
$$;

revoke all on function public.bootstrap_initial_companies() from public, anon;
grant execute on function public.bootstrap_initial_companies() to authenticated;

commit;
