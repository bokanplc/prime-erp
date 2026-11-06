create index if not exists idx_company_policy_documents_company_creator
  on public.company_policy_documents(company_id,created_by);
