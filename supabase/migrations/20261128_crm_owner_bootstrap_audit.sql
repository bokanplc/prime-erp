-- Applied migration: first owner bootstrap and audit triggers for BOKAN Sales CRM
insert into public.crm_organizations(name) select 'BlackRock Investment Plc' where not exists(select 1 from public.crm_organizations);
create or replace function public.crm_initialize_first_owner(p_full_name text) returns jsonb language plpgsql security definer set search_path = '' as $body$
declare v_org uuid; v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if length(trim(coalesce(p_full_name,'')))<2 then raise exception 'Please enter your full name'; end if;
 perform pg_advisory_xact_lock(hashtext('bokan_sales_crm_first_owner'));
 if exists(select 1 from public.crm_memberships) then raise exception 'Workspace already initialized. Ask the workspace owner for an invitation.'; end if;
 select id into v_org from public.crm_organizations order by created_at limit 1;
 if v_org is null then raise exception 'CRM organization is not configured'; end if;
 insert into public.crm_memberships(organization_id,user_id,full_name,role,active) values(v_org,v_uid,trim(p_full_name),'owner',true);
 return jsonb_build_object('organization_id',v_org,'role','owner');
end;
$body$;
grant execute on function public.crm_initialize_first_owner(text) to authenticated;
create or replace function private.crm_audit_row() returns trigger language plpgsql security definer set search_path = '' as $body$
declare v_org uuid; v_id uuid; v_before jsonb; v_after jsonb;
begin
 if TG_OP='DELETE' then v_before:=to_jsonb(OLD); v_org:=(v_before->>'organization_id')::uuid; v_id:=(v_before->>'id')::uuid;
 elsif TG_OP='UPDATE' then v_before:=to_jsonb(OLD); v_after:=to_jsonb(NEW); v_org:=(v_after->>'organization_id')::uuid; v_id:=(v_after->>'id')::uuid;
 else v_after:=to_jsonb(NEW); v_org:=(v_after->>'organization_id')::uuid; v_id:=(v_after->>'id')::uuid; end if;
 insert into public.crm_audit_log(organization_id,actor_user_id,entity_type,entity_id,action,before_data,after_data) values(v_org,auth.uid(),TG_TABLE_NAME,v_id,TG_OP,v_before,v_after);
 if TG_OP='DELETE' then return OLD; else return NEW; end if;
end;
$body$;
drop trigger if exists crm_audit_leads on public.crm_leads;
create trigger crm_audit_leads after insert or update or delete on public.crm_leads for each row execute function private.crm_audit_row();
drop trigger if exists crm_audit_tasks on public.crm_tasks;
create trigger crm_audit_tasks after insert or update or delete on public.crm_tasks for each row execute function private.crm_audit_row();
drop trigger if exists crm_audit_proforma_requests on public.crm_proforma_requests;
create trigger crm_audit_proforma_requests after insert or update or delete on public.crm_proforma_requests for each row execute function private.crm_audit_row();
