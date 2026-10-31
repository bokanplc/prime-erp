do $$
declare
  v_prime_id uuid;
  v_blackrock_id uuid;
begin
  select id into v_blackrock_id
    from public.companies
   where code = 'BLACKROCK' and is_active = true;
  if v_blackrock_id is null then
    raise exception 'BlackRock company record is missing or inactive; refusing Prime decommission.';
  end if;

  select id into v_prime_id
    from public.companies
   where code = 'PRIME';
  if v_prime_id is null then
    raise notice 'Prime company already decommissioned; no action required.';
    return;
  end if;

  -- Remove restrictive child rows first, then the remaining Prime-owned data.
  delete from public.proformas
   where company_id = v_prime_id or company_code = 'PRIME';
  delete from public.journal_lines where company_id = v_prime_id;
  delete from public.journal_entries where company_id = v_prime_id;
  delete from public.ledger_accounts where company_id = v_prime_id;
  delete from public.fiscal_periods where company_id = v_prime_id;
  delete from public.delivery_orders where company_id = v_prime_id;
  delete from public.supply_shipments where company_id = v_prime_id;

  delete from public.companies where id = v_prime_id;

  if exists (select 1 from public.companies where code = 'PRIME') then
    raise exception 'Prime company record remains after decommission.';
  end if;
  if not exists (select 1 from public.companies where id = v_blackrock_id and code = 'BLACKROCK' and is_active = true) then
    raise exception 'BlackRock company record changed unexpectedly during decommission.';
  end if;
end
$$;
