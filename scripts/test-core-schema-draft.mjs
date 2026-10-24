#!/usr/bin/env node
import fs from 'node:fs';
import assert from 'node:assert/strict';

const sql = fs.readFileSync('docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql', 'utf8');
const checks = [
  [/create table if not exists public\.companies/i, 'Company master table exists'],
  [/create table if not exists public\.profiles[\s\S]*?references auth\.users\(id\)/i, 'Profiles are linked to Supabase Auth users'],
  [/create table if not exists public\.company_bank_accounts/i, 'Company bank account table exists'],
  [/create table if not exists public\.custom_terms/i, 'Company-scoped custom Proforma terms table exists'],
  [/create table if not exists public\.proformas/i, 'Proforma persistence table exists'],
  [/delivery_terms text not null default ''/i, 'Delivery terms are persisted'],
  [/constraint proformas_company_number_version_uq unique\(company_code,proforma_no,version_no\)/i, 'Proforma number/version uniqueness is company-scoped'],
  [/alter table public\.companies enable row level security/i, 'RLS is enabled on companies'],
  [/alter table public\.profiles enable row level security/i, 'RLS is enabled on profiles'],
  [/alter table public\.company_bank_accounts enable row level security/i, 'RLS is enabled on bank accounts'],
  [/alter table public\.custom_terms enable row level security/i, 'RLS is enabled on custom Proforma terms'],
  [/alter table public\.proformas enable row level security/i, 'RLS is enabled on proformas'],
  [/create policy proformas_select_member[\s\S]*?p\.company_code = proformas\.company_code/i, 'Proforma reads enforce company scope'],
  [/create policy custom_terms_select_member[\s\S]*?custom_terms\.company_code/i, 'Custom-term reads enforce company scope'],
  [/create policy custom_terms_insert_member[\s\S]*?created_by = \(select auth\.uid\(\)\)/i, 'Custom-term writes enforce creator identity and company scope'],
  [/status, created_by, updated_by[\s\S]*?\(select auth\.uid\(\)\), \(select auth\.uid\(\)\)/i, 'Atomic save derives creator and updater from authenticated identity'],
  [/create or replace function public\.bokan_save_proforma[\s\S]*?security invoker/i, 'Public proforma RPC wrapper remains SECURITY INVOKER'],
  [/create or replace function private\.bokan_save_proforma[\s\S]*?security definer[\s\S]*?set search_path = ''/i, 'Privileged implementation is isolated in private schema with a pinned empty search_path'],
  [/revoke all on function public\.bokan_save_proforma\(text,uuid,jsonb\) from public, anon/i, 'Public wrapper is not executable by anon or PUBLIC'],
  [/revoke all on function private\.bokan_save_proforma\(text,uuid,jsonb\) from public, anon/i, 'Private implementation is not executable by anon or PUBLIC'],
  [/pg_advisory_xact_lock/i, 'Number allocation uses a transaction lock'],
  [/Not authorized to revise this proforma/, 'Sales users cannot revise another user\u2019s proforma without a supervisory role'],
  [/proformas_vat_total_consistency_check/i, 'VAT and grand total arithmetic is constrained'],
  [/proformas_withholding_math_check/i, 'Withholding is checked against the configured threshold and rate'],
  [/proformas_net_payable_math_check/i, 'Net payable is checked against gross less withholding'],
  [/Tax, discount, withholding and date fields have invalid JSON types/, 'Financial settings reject string-valued numeric inputs before casting'],
  [/Customer and optional text fields must be JSON strings/, 'Customer/contact text fields reject malformed JSON objects and arrays'],
  [/Each commercial term must be a string/, 'Commercial terms reject non-string JSON values'],
  [/jsonb_typeof\(item\.value->'qty'\) is distinct from 'number'[\s\S]*?jsonb_typeof\(item\.value->'unit_price'\) is distinct from 'number'/, 'Line item quantities and prices must be JSON numbers'],
  [/Line items must contain objects with a text description and numeric quantity\/unit price/, 'Malformed item JSON is rejected before numeric casts'],
  [/Proforma number sequence exhausted/i, 'Proforma numbering has a defined four-digit upper bound'],
  [/revoke all on public\.companies, public\.profiles, public\.company_bank_accounts, public\.custom_terms, public\.proformas from anon, authenticated/i, 'Table grants start from least privilege'],
  [/insert into public\.companies[\s\S]*?on conflict\(code\) do nothing/i, 'Company seed is repeatable without overwriting edited issuer settings'],
];

const failures = [];
for (const [pattern, description] of checks) {
  if (!pattern.test(sql)) failures.push(description);
}
if ((sql.match(/\bcreate or replace function public\.bokan_save_proforma/g) || []).length !== 1) {
  failures.push('Atomic proforma save RPC must have exactly one definition');
}
if ((sql.match(/\bcommit;/gi) || []).length !== 1) {
  failures.push('Schema draft must contain exactly one final COMMIT');
}
if (!sql.includes("and pf.proforma_no ~ ('^' || v_prefix || '[0-9]{4}$');")) {
  failures.push('Atomic save RPC must use a complete anchored four-digit prefix pattern');
}
const saveStart = sql.indexOf('create or replace function private.bokan_save_proforma');
const saveBodyStart = sql.indexOf('as $$', saveStart);
const saveEnd = sql.indexOf('$$;', saveBodyStart + 5);
const saveFunction = sql.slice(saveStart, saveEnd);
if (!/pg_advisory_xact_lock[\s\S]*?insert into public\.proformas[\s\S]*?returning \* into v_row[\s\S]*?return v_row;/.test(saveFunction)) {
  failures.push('Proforma number lock must remain held through the row insert and return');
}
if (/create or replace function public\.bokan_next_proforma_number/.test(sql)) {
  failures.push('Unsafe candidate-only numbering RPC must not remain in the schema draft');
}
if (!/if v_next >= 9999 then[\s\S]*?raise exception 'Proforma number sequence exhausted/.test(sql)) {
  failures.push('Numbering upper bound must be enforced before formatting the result');
}
if (!/v_subtotal := round\(v_gross \/ \(1 \+ v_vat_rate \/ 100\),2\)/.test(sql)) {
  failures.push('Atomic save must calculate the VAT-exclusive subtotal from the pre-discount VAT-inclusive line prices so the displayed discount row reconciles.');
}

if (!/constraint proformas_vat_total_consistency_check check \(abs\(grand_total - subtotal_before_vat - vat_amount \+ discount_amount\) <= 0\.02\)/.test(sql)) {
  failures.push('Grand total must equal subtotal plus VAT less the displayed discount.');
}
if (!/v_withholding_amount := case[\s\S]*?round\(v_grand_total \* v_withholding_rate \/ 100,2\)/.test(sql)) {
  failures.push('Atomic save must calculate withholding from VAT-inclusive grand total.');
}
if (!/v_company\.tin, v_banks, v_items/.test(sql)) {
  failures.push('Issuer TIN and active bank details must be snapshotted from database rows, not client payload.');
}
if (!/where b\.company_code = p_company and b\.active/.test(sql)) {
  failures.push('Issuer snapshot must exclude inactive bank accounts.');
}
if (/p_payload->>'companyTinSnapshot'|p_payload->'banks'/.test(sql)) {
  failures.push('Atomic save must not trust client-supplied issuer TIN or bank snapshots.');
}
if (/p_payload->>'grandTotal'|p_payload->>'subtotalBeforeVAT'|p_payload->>'vatAmount'/.test(sql)) {
  failures.push('Atomic save must not trust client-calculated totals.');
}
if (/create or replace function public\.bokan_save_proforma[\s\S]*?security definer/i.test(sql)) failures.push('Public proforma RPC must not be SECURITY DEFINER');
if (!/create or replace function private\.bokan_save_proforma[\s\S]*?security definer[\s\S]*?set search_path = ''/i.test(sql)) failures.push('Privileged implementation must be in private schema with an empty search_path');
if (/create policy proformas_insert_member/i.test(sql)) failures.push('Direct client proforma inserts must not be allowed; inserts go through the trusted RPC');
if (!/v_profile public\.profiles%rowtype[\s\S]*?if \(select auth\.uid\(\)\) is null[\s\S]*?Not authorized for this company/i.test(sql)) failures.push('Private trusted write must validate authenticated identity and company membership');
if (!/grant select on public\.proformas to authenticated/i.test(sql)) failures.push('Authenticated users need read-only proforma table access');
if (/grant select, insert on public\.proformas to authenticated/i.test(sql)) failures.push('Authenticated clients must not have direct proforma INSERT privilege');
if (!/company_bank_accounts\.company_code/.test(sql)) failures.push('Bank account RLS must qualify the outer company_code');
if (failures.length) {
  console.error('Core schema draft checks failed:');
  failures.forEach(f => console.error(' - ' + f));
  process.exit(1);
}
console.log('Core schema draft checks passed (' + checks.length + ' checks plus integrity assertions).');
