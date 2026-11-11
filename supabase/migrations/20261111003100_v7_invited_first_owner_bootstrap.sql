-- One-time, invite-gated bootstrap for the first V7 owner.
-- Creates only the two company shells and the authenticated first owner's memberships.
-- No legacy users, customers, products, stock, prices, transactions or balances are imported.
begin;

create or replace function public.bootstrap_initial_companies()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_invited_at timestamptz;
  actor_email_confirmed_at timestamptz;
  prime_company_id uuid;
  blackrock_company_id uuid;
begin
  if actor_id is null then
    raise exception 'Sign in before initializing BOKAN ERP.' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bokan-erp-v7-first-owner-bootstrap', 0));

  select u.invited_at, u.email_confirmed_at
    into actor_invited_at, actor_email_confirmed_at
  from auth.users u
  where u.id = actor_id;

  if actor_invited_at is null or actor_email_confirmed_at is null then
    raise exception 'The first owner must use a verified account invited by the Supabase project administrator.'
      using errcode = '42501';
  end if;

  if exists (select 1 from public.companies)
     or exists (select 1 from public.company_memberships) then
    raise exception 'Initial company setup has already been completed.' using errcode = '55000';
  end if;

  insert into public.companies (legal_name, display_name, currency_code, vat_rate_bps)
  values ('Prime Investment Group', 'Prime Investment Group', 'ETB', 1500)
  returning id into prime_company_id;

  insert into public.companies (legal_name, display_name, currency_code, vat_rate_bps)
  values ('BlackRock Investment PLC', 'BlackRock Investment PLC', 'ETB', 1500)
  returning id into blackrock_company_id;

  insert into public.company_memberships (company_id, user_id, role, is_active)
  values
    (prime_company_id, actor_id, 'owner', true),
    (blackrock_company_id, actor_id, 'owner', true);

  return prime_company_id;
end;
$$;

revoke all on function public.bootstrap_initial_companies() from public, anon;
grant execute on function public.bootstrap_initial_companies() to authenticated;

commit;
