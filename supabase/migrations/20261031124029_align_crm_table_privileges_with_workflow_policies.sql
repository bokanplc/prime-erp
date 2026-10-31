-- CRM write permissions match the row-level policies already defined for these workflows.
-- Activity history and assignment history remain append-only.
revoke delete on table public.customers from authenticated;
grant update on table public.crm_opportunities, public.crm_after_sales_tasks to authenticated;
revoke delete on table public.crm_opportunities, public.crm_after_sales_tasks from authenticated;
revoke update, delete on table public.crm_activities, public.crm_assignment_events from authenticated;
revoke insert, update, delete on table public.crm_customer_assignments from authenticated;
