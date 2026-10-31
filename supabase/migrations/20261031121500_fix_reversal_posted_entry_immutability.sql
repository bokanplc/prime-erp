-- Correct reversal sequencing: set the reversal link while draft, then post immutably.
create or replace function public.reverse_journal_entry(p_company_id uuid,p_journal_entry_id uuid,p_reversal_number text,p_reversal_date date,p_memo text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_source public.journal_entries%rowtype; v_reversal_id uuid; v_user uuid:=(select auth.uid());
begin
 if v_user is null or not exists(select 1 from public.company_memberships m where m.company_id=p_company_id and m.user_id=v_user and m.is_active and m.role in ('owner','admin','manager','accountant')) then
  raise exception 'You are not authorized to reverse journals for this company.';
 end if;
 select * into v_source from public.journal_entries where company_id=p_company_id and id=p_journal_entry_id and status='posted' for update;
 if not found then raise exception 'Only a posted journal entry in this company can be reversed.'; end if;
 if exists(select 1 from public.journal_entries r where r.company_id=p_company_id and r.reversed_entry_id=p_journal_entry_id) then raise exception 'This journal entry has already been reversed.'; end if;
 if not exists(select 1 from public.fiscal_periods p where p.company_id=p_company_id and p.status='open' and p_reversal_date between p.start_date and p.end_date) then raise exception 'Reversal date must fall inside an open fiscal period.'; end if;
 insert into public.journal_entries(company_id,journal_number,journal_date,memo,source_type,source_id,currency_code,created_by,reversed_entry_id)
 values(p_company_id,p_reversal_number,p_reversal_date,coalesce(p_memo,'Reversal of '||v_source.journal_number),'journal_reversal',p_journal_entry_id,v_source.currency_code,v_user,p_journal_entry_id)
 returning id into v_reversal_id;
 insert into public.journal_lines(company_id,journal_entry_id,line_number,account_id,description,debit,credit)
 select p_company_id,v_reversal_id,l.line_number,l.account_id,case when l.description='' then 'Reversal' else 'Reversal: '||l.description end,l.credit,l.debit
 from public.journal_lines l where l.company_id=p_company_id and l.journal_entry_id=p_journal_entry_id order by l.line_number;
 update public.journal_entries set status='posted' where company_id=p_company_id and id=v_reversal_id;
 return v_reversal_id;
end; $$;
revoke all on function public.reverse_journal_entry(uuid,uuid,text,date,text) from public,anon;
grant execute on function public.reverse_journal_entry(uuid,uuid,text,date,text) to authenticated;