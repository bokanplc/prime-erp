-- ONE-TIME FIRST-ADMIN BOOTSTRAP.
-- Run only after the first administrator has been invited/created in Supabase Auth.
-- Replace the placeholder email before running. Execute as postgres in the Supabase SQL editor.
begin;

do $bootstrap$
declare
  target_email text := 'REPLACE-WITH-FIRST-ADMIN-EMAIL';
  target_user_id uuid;
  prime_company_id uuid;
  blackrock_company_id uuid;
begin
  select id into target_user_id
  from auth.users
  where lower(email) = lower(trim(target_email))
  limit 1;

  if target_user_id is null then
    raise exception 'No Supabase Auth user found for the supplied email. Create/invite the account first.';
  end if;

  select id into prime_company_id
  from public.companies
  where legal_name = 'Prime Investment Group'
  limit 1;

  if prime_company_id is null then
    insert into public.companies (legal_name, display_name, currency_code, vat_rate_bps)
    values ('Prime Investment Group', 'Prime Investment Group', 'ETB', 1500)
    returning id into prime_company_id;
  end if;

  select id into blackrock_company_id
  from public.companies
  where legal_name = 'BlackRock Investment PLC'
  limit 1;

  if blackrock_company_id is null then
    insert into public.companies (legal_name, display_name, currency_code, vat_rate_bps)
    values ('BlackRock Investment PLC', 'BlackRock Investment PLC', 'ETB', 1500)
    returning id into blackrock_company_id;
  end if;

  insert into public.company_memberships (company_id, user_id, role, is_active)
  values
    (prime_company_id, target_user_id, 'admin', true),
    (blackrock_company_id, target_user_id, 'admin', true)
  on conflict (company_id, user_id)
  do update set role = 'admin', is_active = true;
end
$bootstrap$;

commit;
