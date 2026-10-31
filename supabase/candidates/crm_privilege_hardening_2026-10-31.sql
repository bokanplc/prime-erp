-- Applied to Supabase project kafiwnuynjemufnankvi on 2026-10-31.
-- Migration: 20261031081422_restrict_crm_assignment_writes_to_rpc.
-- Removes default/anonymous grants and makes assignment/history writes RPC-only.

begin;

drop policy if exists crm_assignments_manager_insert on public.crm_customer_assignments;
drop policy if exists crm_assignment_events_manager_insert on public.crm_assignment_events;

revoke all on table public.crm_customer_assignments, public.crm_assignment_events,
  public.crm_activities, public.crm_opportunities, public.crm_after_sales_tasks
  from public, anon, authenticated;

grant select on public.crm_customer_assignments to authenticated;
grant select on public.crm_assignment_events to authenticated;
grant select, insert on public.crm_activities to authenticated;
grant select, insert on public.crm_opportunities to authenticated;
grant update (product_description, estimated_quantity, estimated_value, currency_code, required_date, stage, next_action, next_action_date, competitor, notes, owner_user_id) on public.crm_opportunities to authenticated;
grant select, insert on public.crm_after_sales_tasks to authenticated;
grant update (task_type, notes, due_date, status, completed_at, owner_user_id) on public.crm_after_sales_tasks to authenticated;

commit;
