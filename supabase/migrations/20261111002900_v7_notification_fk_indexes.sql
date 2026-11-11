-- Index notification foreign-key columns for efficient recipient cleanup and company-scoped maintenance.
create index if not exists idx_notifications_actor_user_id
  on public.notifications (actor_user_id);

create index if not exists idx_notifications_company_id
  on public.notifications (company_id);
