-- SUPERSEDED DRAFT: The live ledger already records sync_profile_role_on_membership_changes as version 20261031134421.
-- The original applied SQL body has not been recovered. This later equivalent draft is retained for audit only and must never be applied.
drop trigger if exists sync_profile_from_company_membership on public.company_memberships;
create trigger sync_profile_from_company_membership
after insert or update of user_id, company_id, role
on public.company_memberships
for each row execute function private.sync_profile_from_membership();

update public.profiles p
set role=m.role,company_id=m.company_id,updated_at=now()
from public.company_memberships m
where m.user_id=p.id and m.is_active=true and m.company_id=p.company_id;
