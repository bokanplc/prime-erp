create or replace function public.bokan_reassign_customer_owner(
  p_company_id uuid,
  p_customer_id uuid,
  p_new_owner_user_id uuid,
  p_reason text
)
returns public.crm_customer_assignments
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_old_owner uuid;
  v_result public.crm_customer_assignments;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode='28000';
  end if;
  if not (select private.can_manage_company(p_company_id)) then
    raise exception 'Company manager permission required' using errcode='42501';
  end if;
  if p_reason is null or length(btrim(p_reason)) = 0 then
    raise exception 'Reassignment reason is required' using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(p_company_id::text || ':' || p_customer_id::text, 0)
  );
  perform 1
    from public.customers c
   where c.company_id = p_company_id and c.id = p_customer_id;
  if not found then
    raise exception 'Customer not found in selected company' using errcode='23503';
  end if;

  if not exists (
    select 1 from public.company_memberships m
     where m.company_id=p_company_id
       and m.user_id=p_new_owner_user_id
       and m.is_active
       and m.role in ('sales','staff')
  ) then
    raise exception 'New owner must be an active sales or staff member of the selected company' using errcode='23503';
  end if;

  select a.owner_user_id into v_old_owner
    from public.crm_customer_assignments a
   where a.company_id=p_company_id and a.customer_id=p_customer_id;

  insert into public.crm_customer_assignments
    (company_id,customer_id,owner_user_id,assigned_by,assigned_at,updated_at)
  values
    (p_company_id,p_customer_id,p_new_owner_user_id,(select auth.uid()),now(),now())
  on conflict (company_id,customer_id) do update
    set owner_user_id=excluded.owner_user_id,
        assigned_by=excluded.assigned_by,
        assigned_at=excluded.assigned_at,
        updated_at=now()
  returning * into v_result;

  insert into public.crm_assignment_events
    (company_id,customer_id,old_owner_user_id,new_owner_user_id,actor_user_id,reason)
  values
    (p_company_id,p_customer_id,v_old_owner,p_new_owner_user_id,(select auth.uid()),btrim(p_reason));

  return v_result;
end;
$function$;
revoke all on function public.bokan_reassign_customer_owner(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.bokan_reassign_customer_owner(uuid,uuid,uuid,text) to authenticated;
