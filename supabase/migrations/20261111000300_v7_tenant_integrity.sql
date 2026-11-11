-- Enforce tenant-consistent references in every cross-table business relationship.
begin;

alter table public.customers add constraint customers_id_company_unique unique (id, company_id);
alter table public.suppliers add constraint suppliers_id_company_unique unique (id, company_id);
alter table public.crm_leads add constraint crm_leads_id_company_unique unique (id, company_id);
alter table public.sales_documents add constraint sales_documents_id_company_unique unique (id, company_id);
alter table public.purchase_orders add constraint purchase_orders_id_company_unique unique (id, company_id);
alter table public.documents add constraint documents_id_company_unique unique (id, company_id);

alter table public.crm_leads
  add constraint crm_leads_customer_same_company_fk
  foreign key (customer_id, company_id) references public.customers(id, company_id);

alter table public.crm_activities
  add constraint crm_activities_customer_same_company_fk
    foreign key (customer_id, company_id) references public.customers(id, company_id),
  add constraint crm_activities_lead_same_company_fk
    foreign key (lead_id, company_id) references public.crm_leads(id, company_id);

alter table public.sales_documents
  add constraint sales_documents_customer_same_company_fk
  foreign key (customer_id, company_id) references public.customers(id, company_id);

alter table public.sales_document_lines
  add constraint sales_lines_document_same_company_fk
  foreign key (sales_document_id, company_id) references public.sales_documents(id, company_id) on delete cascade;

alter table public.purchase_orders
  add constraint purchase_orders_supplier_same_company_fk
  foreign key (supplier_id, company_id) references public.suppliers(id, company_id);

alter table public.purchase_order_lines
  add constraint purchase_lines_order_same_company_fk
  foreign key (purchase_order_id, company_id) references public.purchase_orders(id, company_id) on delete cascade;

alter table public.direct_costs
  add constraint direct_costs_sales_document_same_company_fk
    foreign key (sales_document_id, company_id) references public.sales_documents(id, company_id),
  add constraint direct_costs_purchase_order_same_company_fk
    foreign key (purchase_order_id, company_id) references public.purchase_orders(id, company_id),
  add constraint direct_costs_exactly_one_parent
    check ((sales_document_id is not null) <> (purchase_order_id is not null));

alter table public.delivery_jobs
  add constraint delivery_jobs_sales_document_same_company_fk
    foreign key (sales_document_id, company_id) references public.sales_documents(id, company_id),
  add constraint delivery_jobs_customer_same_company_fk
    foreign key (customer_id, company_id) references public.customers(id, company_id),
  add constraint delivery_jobs_proof_document_same_company_fk
    foreign key (proof_document_id, company_id) references public.documents(id, company_id);

alter table public.tasks
  add constraint tasks_customer_same_company_fk
    foreign key (customer_id, company_id) references public.customers(id, company_id),
  add constraint tasks_lead_same_company_fk
    foreign key (lead_id, company_id) references public.crm_leads(id, company_id);

alter table public.documents
  add constraint documents_customer_same_company_fk
    foreign key (related_customer_id, company_id) references public.customers(id, company_id),
  add constraint documents_sales_document_same_company_fk
    foreign key (related_sales_document_id, company_id) references public.sales_documents(id, company_id),
  add constraint documents_purchase_order_same_company_fk
    foreign key (related_purchase_order_id, company_id) references public.purchase_orders(id, company_id);

commit;
