create table if not exists public.company_policy_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  document_key text not null check (length(btrim(document_key)) between 1 and 120),
  title text not null check (length(btrim(title)) between 1 and 300),
  version text not null check (length(btrim(version)) between 1 and 80),
  effective_date date,
  content_html text not null,
  is_active boolean not null default true,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint company_policy_documents_version_uq unique(company_id,document_key,version),
  constraint company_policy_documents_creator_membership_fk
    foreign key (company_id,created_by)
    references public.company_memberships(company_id,user_id) on delete restrict
);

create unique index if not exists idx_company_policy_documents_one_active
  on public.company_policy_documents(company_id,document_key)
  where is_active;
create index if not exists idx_company_policy_documents_company_key
  on public.company_policy_documents(company_id,document_key);

alter table public.company_policy_documents enable row level security;
revoke all on public.company_policy_documents from anon, public;
grant select,insert,update,delete on public.company_policy_documents to authenticated;

create policy company_policy_documents_select_member
  on public.company_policy_documents for select to authenticated
  using (private.has_company_membership(company_id));

create policy company_policy_documents_insert_admin
  on public.company_policy_documents for insert to authenticated
  with check (
    private.has_company_role(company_id,array['owner','admin'])
    and created_by = (select auth.uid())
  );

create policy company_policy_documents_update_admin
  on public.company_policy_documents for update to authenticated
  using (private.has_company_role(company_id,array['owner','admin']))
  with check (private.has_company_role(company_id,array['owner','admin']));

create policy company_policy_documents_delete_admin
  on public.company_policy_documents for delete to authenticated
  using (private.has_company_role(company_id,array['owner','admin']));
