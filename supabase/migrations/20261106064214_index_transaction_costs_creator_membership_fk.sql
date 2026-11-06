create index if not exists idx_transaction_costs_company_creator
  on public.transaction_costs(company_id,created_by);
