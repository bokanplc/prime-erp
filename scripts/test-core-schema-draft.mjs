#!/usr/bin/env node
import fs from 'node:fs';
import assert from 'node:assert/strict';

const sql = fs.readFileSync('docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql', 'utf8');
const checks = [
  [/create table if not exists public\.companies/i, 'Company master table exists'],
  [/create table if not exists public\.profiles[\s\S]*?references auth\.users\(id\)/i, 'Profiles are linked to Supabase Auth users'],
  [/create table if not exists public\.company_bank_accounts/i, 'Company bank account table exists'],
  [/create table if not exists public\.proformas/i, 'Proforma persistence table exists'],
  [/delivery_terms text not null default ''/i, 'Delivery terms are persisted'],
  [/constraint proformas_company_number_version_uq unique\(company_code,proforma_no,version_no\)/i, 'Proforma number/version uniqueness is company-scoped'],
  [/alter table public\.companies enable row level security/i, 'RLS is enabled on companies'],
  [/alter table public\.profiles enable row level security/i, 'RLS is enabled on profiles'],
  [/alter table public\.company_bank_accounts enable row level security/i, 'RLS is enabled on bank accounts'],
  [/alter table public\.proformas enable row level security/i, 'RLS is enabled on proformas'],
  [/create policy proformas_select_member[\s\S]*?p\.company_code = proformas\.company_code/i, 'Proforma reads enforce company scope'],
  [/create policy proformas_insert_member[\s\S]*?created_by = \(select auth\.uid\(\)\)[\s\S]*?p\.company_code = proformas\.company_code/i, 'Proforma inserts enforce actor and company scope'],
  [/security invoker/i, 'Numbering RPC is not SECURITY DEFINER'],
  [/pg_advisory_xact_lock/i, 'Number allocation uses a transaction lock'],
  [/revoke all on public\.companies, public\.profiles, public\.company_bank_accounts, public\.proformas from anon, authenticated/i, 'Table grants start from least privilege'],
  [/insert into public\.companies[\s\S]*?on conflict\(code\) do update/i, 'Company seed is repeatable'],
];

const failures = [];
for (const [pattern, description] of checks) {
  if (!pattern.test(sql)) failures.push(description);
}
if (/security definer/i.test(sql)) failures.push('Schema draft must not introduce SECURITY DEFINER functions');
if (!/company_bank_accounts\.company_code/.test(sql)) failures.push('Bank account RLS must qualify the outer company_code');
if (failures.length) {
  console.error('Core schema draft checks failed:');
  failures.forEach(f => console.error(' - ' + f));
  process.exit(1);
}
console.log('Core schema draft checks passed (' + checks.length + ' checks).');
