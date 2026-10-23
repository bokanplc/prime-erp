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
  [/proformas_vat_total_consistency_check/i, 'VAT and grand total arithmetic is constrained'],
  [/proformas_withholding_math_check/i, 'Withholding is checked against the configured threshold and rate'],
  [/proformas_net_payable_math_check/i, 'Net payable is checked against gross less withholding'],
  [/Proforma number sequence exhausted/i, 'Proforma numbering has a defined four-digit upper bound'],
  [/revoke all on public\.companies, public\.profiles, public\.company_bank_accounts, public\.proformas from anon, authenticated/i, 'Table grants start from least privilege'],
  [/insert into public\.companies[\s\S]*?on conflict\(code\) do update/i, 'Company seed is repeatable'],
];

const failures = [];
for (const [pattern, description] of checks) {
  if (!pattern.test(sql)) failures.push(description);
}
if ((sql.match(/\\bcreate or replace function public\\.bokan_save_proforma/g) || []).length !== 1) {
  failures.push('Atomic proforma save RPC must have exactly one definition');
}
if ((sql.match(/\\bcommit;/gi) || []).length !== 1) {
  failures.push('Schema draft must contain exactly one final COMMIT');
}
if (!sql.includes("and pf.proforma_no ~ ('^' || v_prefix || '[0-9]{4}$');")) {
  failures.push('Atomic save RPC must use a complete anchored four-digit prefix pattern');
}
const saveStart = sql.indexOf('create or replace function public.bokan_save_proforma');
const saveBodyStart = sql.indexOf('as $$', saveStart);
const saveEnd = sql.indexOf('$$;', saveBodyStart + 5);
const saveFunction = sql.slice(saveStart, saveEnd);
if (!/pg_advisory_xact_lock[\\s\\S]*?insert into public\\.proformas[\\s\\S]*?returning \\* into v_row[\\s\\S]*?return v_row;/.test(saveFunction)) {
  failures.push('Proforma number lock must remain held through the row insert and return');
}
if (/create or replace function public\\.bokan_next_proforma_number/.test(sql)) {
  failures.push('Unsafe candidate-only numbering RPC must not remain in the schema draft');
}
if (!/if v_next >= 9999 then[\s\S]*?raise exception 'Proforma number sequence exhausted/.test(sql)) {
  failures.push('Numbering upper bound must be enforced before formatting the result');
}
if (/security definer/i.test(sql)) failures.push('Schema draft must not introduce SECURITY DEFINER functions');
if (!/company_bank_accounts\.company_code/.test(sql)) failures.push('Bank account RLS must qualify the outer company_code');
if (failures.length) {
  console.error('Core schema draft checks failed:');
  failures.forEach(f => console.error(' - ' + f));
  process.exit(1);
}
console.log('Core schema draft checks passed (' + checks.length + ' checks plus integrity assertions).');
