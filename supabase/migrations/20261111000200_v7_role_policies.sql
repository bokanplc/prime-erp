-- Tighten workspace write permissions before enabling any real users.
begin;

drop policy if exists customers_member_access on public.customers;
create policy customers_member_read on public.customers
  for select to authenticated using (private.is_company_member(company_id));
create policy customers_sales_write on public.customers
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy customers_sales_update on public.customers
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy customers_manager_delete on public.customers
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists suppliers_member_access on public.suppliers;
create policy suppliers_member_read on public.suppliers
  for select to authenticated using (private.is_company_member(company_id));
create policy suppliers_purchasing_write on public.suppliers
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]));
create policy suppliers_purchasing_update on public.suppliers
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]));
create policy suppliers_manager_delete on public.suppliers
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists leads_member_access on public.crm_leads;
create policy leads_member_read on public.crm_leads
  for select to authenticated using (private.is_company_member(company_id));
create policy leads_sales_write on public.crm_leads
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy leads_sales_update on public.crm_leads
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy leads_manager_delete on public.crm_leads
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists crm_activities_member_access on public.crm_activities;
create policy crm_activities_member_read on public.crm_activities
  for select to authenticated using (private.is_company_member(company_id));
create policy crm_activities_sales_write on public.crm_activities
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy crm_activities_sales_update on public.crm_activities
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy crm_activities_manager_delete on public.crm_activities
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists sales_documents_member_access on public.sales_documents;
create policy sales_documents_member_read on public.sales_documents
  for select to authenticated using (private.is_company_member(company_id));
create policy sales_documents_sales_write on public.sales_documents
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy sales_documents_sales_update on public.sales_documents
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy sales_documents_manager_delete on public.sales_documents
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists sales_document_lines_member_access on public.sales_document_lines;
create policy sales_lines_member_read on public.sales_document_lines
  for select to authenticated using (private.is_company_member(company_id));
create policy sales_lines_sales_write on public.sales_document_lines
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy sales_lines_sales_update on public.sales_document_lines
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales']::public.company_role[]));
create policy sales_lines_manager_delete on public.sales_document_lines
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists purchase_orders_member_access on public.purchase_orders;
create policy purchase_orders_member_read on public.purchase_orders
  for select to authenticated using (private.is_company_member(company_id));
create policy purchase_orders_purchasing_write on public.purchase_orders
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]));
create policy purchase_orders_purchasing_update on public.purchase_orders
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]));
create policy purchase_orders_manager_delete on public.purchase_orders
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists purchase_order_lines_member_access on public.purchase_order_lines;
create policy purchase_lines_member_read on public.purchase_order_lines
  for select to authenticated using (private.is_company_member(company_id));
create policy purchase_lines_purchasing_write on public.purchase_order_lines
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]));
create policy purchase_lines_purchasing_update on public.purchase_order_lines
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','purchasing']::public.company_role[]));
create policy purchase_lines_manager_delete on public.purchase_order_lines
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists direct_costs_member_access on public.direct_costs;
create policy direct_costs_member_read on public.direct_costs
  for select to authenticated using (private.is_company_member(company_id));
create policy direct_costs_commercial_write on public.direct_costs
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]));
create policy direct_costs_commercial_update on public.direct_costs
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]));
create policy direct_costs_manager_delete on public.direct_costs
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists delivery_jobs_member_access on public.delivery_jobs;
create policy delivery_jobs_member_read on public.delivery_jobs
  for select to authenticated using (private.is_company_member(company_id));
create policy delivery_jobs_operations_write on public.delivery_jobs
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales','operations']::public.company_role[]));
create policy delivery_jobs_operations_update on public.delivery_jobs
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales','operations']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales','operations']::public.company_role[]));
create policy delivery_jobs_manager_delete on public.delivery_jobs
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists tasks_member_access on public.tasks;
create policy tasks_member_read on public.tasks
  for select to authenticated using (private.is_company_member(company_id));
create policy tasks_member_write on public.tasks
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]));
create policy tasks_member_update on public.tasks
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]));
create policy tasks_manager_delete on public.tasks
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

drop policy if exists documents_member_access on public.documents;
create policy documents_member_read on public.documents
  for select to authenticated using (private.is_company_member(company_id));
create policy documents_workspace_write on public.documents
  for insert to authenticated
  with check (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]));
create policy documents_workspace_update on public.documents
  for update to authenticated
  using (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]))
  with check (private.has_company_role(company_id, array['owner','manager','sales','purchasing','operations']::public.company_role[]));
create policy documents_manager_delete on public.documents
  for delete to authenticated
  using (private.has_company_role(company_id, array['owner','manager']::public.company_role[]));

commit;
