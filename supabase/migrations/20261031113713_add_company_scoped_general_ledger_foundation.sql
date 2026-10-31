-- Company-scoped general ledger foundation for BOKAN ERP V6.7.
-- No historical business records are imported; all journal posting remains explicit.
begin;

create table public.ledger_accounts (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete restrict,
 account_code text not null, account_name text not null,
 account_type text not null check (account_type in ('asset','liability','equity','revenue','expense','contra_asset','contra_liability','contra_equity','contra_revenue','contra_expense')),
 normal_balance text not null check (normal_balance in ('debit','credit')),
 parent_account_id uuid, is_active boolean not null default true,
 is_system_account boolean not null default false, description text,
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,account_code), unique(company_id,id),
 foreign key(company_id,parent_account_id) references public.ledger_accounts(company_id,id) on delete restrict,
 check(parent_account_id is null or parent_account_id <> id)
);

create table public.fiscal_periods (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete restrict,
 period_name text not null, start_date date not null, end_date date not null,
 status text not null default 'open' check(status in ('open','closed','locked')),
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(),
 unique(company_id,period_name), unique(company_id,id), check(end_date >= start_date)
);

create table public.journal_entries (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete restrict,
 journal_number text not null, journal_date date not null default current_date,
 memo text not null default '', source_type text, source_id uuid,
 currency_code text not null default 'ETB' check(currency_code ~ '^[A-Z]{3}$'),
 status text not null default 'draft' check(status in ('draft','posted')),
 total_debit numeric(18,2) not null default 0 check(total_debit >= 0),
 total_credit numeric(18,2) not null default 0 check(total_credit >= 0),
 created_by uuid not null default auth.uid() references auth.users(id),
 posted_by uuid references auth.users(id), posted_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,journal_number), unique(company_id,id),
 check((status='draft' and posted_by is null and posted_at is null) or (status='posted' and posted_by is not null and posted_at is not null))
);
create unique index journal_entries_company_source_unique on public.journal_entries(company_id,source_type,source_id) where source_type is not null and source_id is not null;

create table public.journal_lines (
 id uuid primary key default gen_random_uuid(), company_id uuid not null,
 journal_entry_id uuid not null, line_number integer not null check(line_number > 0),
 account_id uuid not null, description text not null default '',
 debit numeric(18,2) not null default 0 check(debit >= 0),
 credit numeric(18,2) not null default 0 check(credit >= 0),
 created_at timestamptz not null default now(),
 unique(journal_entry_id,line_number),
 foreign key(company_id,journal_entry_id) references public.journal_entries(company_id,id) on delete restrict,
 foreign key(company_id,account_id) references public.ledger_accounts(company_id,id) on delete restrict,
 check((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);

create index ledger_accounts_company_type_idx on public.ledger_accounts(company_id,account_type,account_code);
create index fiscal_periods_company_dates_idx on public.fiscal_periods(company_id,start_date,end_date);
create index journal_entries_company_date_idx on public.journal_entries(company_id,journal_date desc);
create index journal_entries_company_status_idx on public.journal_entries(company_id,status,journal_date desc);
create index journal_lines_company_account_idx on public.journal_lines(company_id,account_id);

create or replace function public.validate_journal_entry_posting()
returns trigger language plpgsql set search_path = '' as $$
declare v_debit numeric(18,2); v_credit numeric(18,2); v_count integer; v_period_ok boolean;
begin
 if tg_table_name='journal_entries' then
  if tg_op='UPDATE' and old.status='posted' then
   raise exception 'Posted journal entries are immutable; use a separately authorized reversal workflow.';
  end if;
  if new.status='posted' and (tg_op='INSERT' or old.status <> 'posted') then
   if not exists(select 1 from public.company_memberships m where m.company_id=new.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')) then
    raise exception 'Only an authorized finance or company manager may post journals.';
   end if;
   select exists(select 1 from public.fiscal_periods p where p.company_id=new.company_id and p.status='open' and new.journal_date between p.start_date and p.end_date) into v_period_ok;
   if not v_period_ok then raise exception 'Journal date must fall inside an open fiscal period.'; end if;
   select count(*),coalesce(sum(debit),0),coalesce(sum(credit),0) into v_count,v_debit,v_credit from public.journal_lines l where l.company_id=new.company_id and l.journal_entry_id=new.id;
   if v_count < 2 or v_debit <= 0 or v_debit <> v_credit then raise exception 'A journal requires at least two lines and equal positive debit and credit totals.'; end if;
   if exists(select 1 from public.journal_lines l join public.ledger_accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=new.company_id and l.journal_entry_id=new.id and not a.is_active) then
    raise exception 'A journal cannot post to an inactive account.';
   end if;
   new.total_debit:=v_debit; new.total_credit:=v_credit; new.posted_by:=(select auth.uid()); new.posted_at:=now();
  end if;
  new.updated_at:=now(); return new;
 end if;
 if tg_table_name='journal_lines' then
  if exists(select 1 from public.journal_entries e where e.company_id=new.company_id and e.id=new.journal_entry_id and e.status='posted') then raise exception 'Lines on a posted journal entry cannot be changed.'; end if;
  return new;
 end if;
 return new;
end; $$;

create trigger journal_entries_validate_posting before insert or update on public.journal_entries for each row execute function public.validate_journal_entry_posting();
create trigger journal_lines_immutable_after_post before insert or update on public.journal_lines for each row execute function public.validate_journal_entry_posting();

create or replace function public.refresh_draft_journal_totals()
returns trigger language plpgsql set search_path = '' as $$
declare v_entry_id uuid; v_company_id uuid;
begin
 v_entry_id:=coalesce(new.journal_entry_id,old.journal_entry_id);
 v_company_id:=coalesce(new.company_id,old.company_id);
 update public.journal_entries e set
  total_debit=(select coalesce(sum(l.debit),0) from public.journal_lines l where l.company_id=v_company_id and l.journal_entry_id=v_entry_id),
  total_credit=(select coalesce(sum(l.credit),0) from public.journal_lines l where l.company_id=v_company_id and l.journal_entry_id=v_entry_id),
  updated_at=now()
 where e.company_id=v_company_id and e.id=v_entry_id and e.status='draft';
 return coalesce(new,old);
end; $$;
create trigger journal_lines_refresh_totals after insert or update or delete on public.journal_lines for each row execute function public.refresh_draft_journal_totals();

alter table public.ledger_accounts enable row level security;
alter table public.fiscal_periods enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;

create policy ledger_accounts_select_member on public.ledger_accounts for select to authenticated using(private.has_company_membership(company_id));
create policy ledger_accounts_manage_finance on public.ledger_accounts for all to authenticated
 using(exists(select 1 from public.company_memberships m where m.company_id=ledger_accounts.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')))
 with check(exists(select 1 from public.company_memberships m where m.company_id=ledger_accounts.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')) and created_by=(select auth.uid()));

create policy fiscal_periods_select_member on public.fiscal_periods for select to authenticated using(private.has_company_membership(company_id));
create policy fiscal_periods_manage_finance on public.fiscal_periods for all to authenticated
 using(exists(select 1 from public.company_memberships m where m.company_id=fiscal_periods.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')))
 with check(exists(select 1 from public.company_memberships m where m.company_id=fiscal_periods.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')) and created_by=(select auth.uid()));

create policy journal_entries_select_member on public.journal_entries for select to authenticated using(private.has_company_membership(company_id));
create policy journal_entries_insert_finance on public.journal_entries for insert to authenticated with check(created_by=(select auth.uid()) and exists(select 1 from public.company_memberships m where m.company_id=journal_entries.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')));
create policy journal_entries_update_draft_finance on public.journal_entries for update to authenticated
 using(status='draft' and exists(select 1 from public.company_memberships m where m.company_id=journal_entries.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')))
 with check(created_by=(select auth.uid()) and exists(select 1 from public.company_memberships m where m.company_id=journal_entries.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')));

create policy journal_lines_select_member on public.journal_lines for select to authenticated using(private.has_company_membership(company_id));
create policy journal_lines_insert_draft_finance on public.journal_lines for insert to authenticated with check(
 exists(select 1 from public.company_memberships m where m.company_id=journal_lines.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant'))
 and exists(select 1 from public.journal_entries e where e.company_id=journal_lines.company_id and e.id=journal_lines.journal_entry_id and e.status='draft'));
create policy journal_lines_update_draft_finance on public.journal_lines for update to authenticated
 using(exists(select 1 from public.company_memberships m where m.company_id=journal_lines.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')) and exists(select 1 from public.journal_entries e where e.company_id=journal_lines.company_id and e.id=journal_lines.journal_entry_id and e.status='draft'))
 with check(exists(select 1 from public.company_memberships m where m.company_id=journal_lines.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')) and exists(select 1 from public.journal_entries e where e.company_id=journal_lines.company_id and e.id=journal_lines.journal_entry_id and e.status='draft'));
create policy journal_lines_delete_draft_finance on public.journal_lines for delete to authenticated using(
 exists(select 1 from public.company_memberships m where m.company_id=journal_lines.company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant'))
 and exists(select 1 from public.journal_entries e where e.company_id=journal_lines.company_id and e.id=journal_lines.journal_entry_id and e.status='draft'));

grant select,insert,update on public.ledger_accounts to authenticated;
grant select,insert,update on public.fiscal_periods to authenticated;
grant select,insert,update on public.journal_entries to authenticated;
grant select,insert,update,delete on public.journal_lines to authenticated;
commit;
