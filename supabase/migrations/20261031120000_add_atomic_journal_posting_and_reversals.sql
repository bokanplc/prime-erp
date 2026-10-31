-- Atomic journal posting and auditable reversal workflows.
begin;
alter table public.journal_entries add column reversed_entry_id uuid,
 add constraint journal_entries_reversal_same_company_fk foreign key(company_id,reversed_entry_id) references public.journal_entries(company_id,id) on delete restrict;
create unique index journal_entries_one_reversal_per_source on public.journal_entries(company_id,reversed_entry_id) where reversed_entry_id is not null;
create or replace function public.post_journal_entry(p_company_id uuid,p_journal_number text,p_journal_date date,p_memo text,p_currency_code text,p_lines jsonb,p_source_type text default null,p_source_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid := (select auth.uid()); v_entry_id uuid; v_debit numeric(18,2); v_credit numeric(18,2); v_count integer;
begin
 if v_user is null then raise exception 'Authentication is required.'; end if;
 if not exists(select 1 from public.company_memberships m where m.company_id=p_company_id and m.user_id=v_user and m.is_active and m.role in ('owner','admin','manager','accountant')) then raise exception 'You are not authorized to post journals for this company.'; end if;
 if jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)<2 then raise exception 'At least two journal lines are required.'; end if;
 if (p_source_type is null) <> (p_source_id is null) then raise exception 'Source type and source ID must be supplied together.'; end if;
 select count(*),coalesce(sum((x->>'debit')::numeric),0),coalesce(sum((x->>'credit')::numeric),0) into v_count,v_debit,v_credit from jsonb_array_elements(p_lines) x;
 if v_count<2 or v_debit<=0 or v_debit<>v_credit then raise exception 'Journal lines must have equal positive debit and credit totals.'; end if;
 if exists(select 1 from jsonb_array_elements(p_lines) x where x->>'account_id' is null or x->>'line_number' is null or coalesce((x->>'debit')::numeric,0)<0 or coalesce((x->>'credit')::numeric,0)<0 or not ((coalesce((x->>'debit')::numeric,0)>0 and coalesce((x->>'credit')::numeric,0)=0) or (coalesce((x->>'credit')::numeric,0)>0 and coalesce((x->>'debit')::numeric,0)=0))) then raise exception 'Each journal line must contain a valid account, line number and one-sided positive amount.'; end if;
 if exists(select 1 from jsonb_array_elements(p_lines) x left join public.ledger_accounts a on a.company_id=p_company_id and a.id=(x->>'account_id')::uuid where a.id is null or not a.is_active) then raise exception 'Every journal account must be active and belong to the selected company.'; end if;
 if not exists(select 1 from public.fiscal_periods p where p.company_id=p_company_id and p.status='open' and p_journal_date between p.start_date and p.end_date) then raise exception 'Journal date must fall inside an open fiscal period.'; end if;
 insert into public.journal_entries(company_id,journal_number,journal_date,memo,source_type,source_id,currency_code,created_by)
 values(p_company_id,p_journal_number,p_journal_date,coalesce(p_memo,''),p_source_type,p_source_id,coalesce(p_currency_code,'ETB'),v_user) returning id into v_entry_id;
 insert into public.journal_lines(company_id,journal_entry_id,line_number,account_id,description,debit,credit)
 select p_company_id,v_entry_id,(x->>'line_number')::integer,(x->>'account_id')::uuid,coalesce(x->>'description',''),coalesce((x->>'debit')::numeric,0),coalesce((x->>'credit')::numeric,0) from jsonb_array_elements(p_lines) x;
 update public.journal_entries set status='posted' where id=v_entry_id and company_id=p_company_id;
 return v_entry_id;
end; $$;
create or replace function public.reverse_journal_entry(p_company_id uuid,p_journal_entry_id uuid,p_reversal_number text,p_reversal_date date,p_memo text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_source public.journal_entries%rowtype; v_lines jsonb; v_reversal_id uuid;
begin
 if not exists(select 1 from public.company_memberships m where m.company_id=p_company_id and m.user_id=(select auth.uid()) and m.is_active and m.role in ('owner','admin','manager','accountant')) then raise exception 'You are not authorized to reverse journals for this company.'; end if;
 select * into v_source from public.journal_entries where company_id=p_company_id and id=p_journal_entry_id and status='posted' for update;
 if not found then raise exception 'Only a posted journal entry in this company can be reversed.'; end if;
 if exists(select 1 from public.journal_entries r where r.company_id=p_company_id and r.reversed_entry_id=p_journal_entry_id) then raise exception 'This journal entry has already been reversed.'; end if;
 select jsonb_agg(jsonb_build_object('line_number',l.line_number,'account_id',l.account_id,'description',case when l.description='' then 'Reversal' else 'Reversal: '||l.description end,'debit',l.credit,'credit',l.debit) order by l.line_number) into v_lines from public.journal_lines l where l.company_id=p_company_id and l.journal_entry_id=p_journal_entry_id;
 v_reversal_id:=public.post_journal_entry(p_company_id,p_reversal_number,p_reversal_date,coalesce(p_memo,'Reversal of '||v_source.journal_number),v_source.currency_code,v_lines,'journal_reversal',p_journal_entry_id);
 update public.journal_entries set reversed_entry_id=p_journal_entry_id where company_id=p_company_id and id=v_reversal_id;
 return v_reversal_id;
end; $$;
revoke all on function public.post_journal_entry(uuid,text,date,text,text,jsonb,text,uuid) from public,anon;
revoke all on function public.reverse_journal_entry(uuid,uuid,text,date,text) from public,anon;
grant execute on function public.post_journal_entry(uuid,text,date,text,text,jsonb,text,uuid) to authenticated;
grant execute on function public.reverse_journal_entry(uuid,uuid,text,date,text) to authenticated;
commit;