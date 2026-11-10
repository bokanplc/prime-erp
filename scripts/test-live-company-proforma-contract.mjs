#!/usr/bin/env node
import fs from 'node:fs';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const entry = fs.readFileSync('staging/index.html', 'utf8');
const sql = fs.readFileSync('supabase/candidates/live_company_proforma.sql', 'utf8');

assert.equal(entry, source, 'The full staging entry must match the reviewed full ERP source.');

const panelIds = [...source.matchAll(/<section\b[^>]*\bid=["']([^"']+)["'][^>]*>/gi)].map(match => match[1]);
assert.equal(panelIds.length, 91, 'The reviewed V6.7 source must retain all 91 section panels.');
assert.equal(new Set(panelIds).size, panelIds.length, 'Every V6.7 section panel must have a unique DOM id.');

const navStart = source.indexOf('const NAV_TREE = [');
const navEnd = source.indexOf('\n];', navStart);
assert.ok(navStart >= 0 && navEnd > navStart, 'The full V6.7 navigation tree must exist.');
const navIds = [...source.slice(navStart, navEnd).matchAll(/\{\s*id:\s*'([^']+)'/g)].map(match => match[1]);
assert.ok(navIds.includes('periodlock') && navIds.includes('periodclose'), 'Period Lock and Period Close Management must have distinct navigation targets.');
assert.ok(navIds.includes('masterdata') && navIds.includes('masterdatagovernance'), 'Master Data Management and Governance must have distinct navigation targets.');
assert.deepEqual([...new Set(navIds.filter((id, index) => navIds.indexOf(id) !== index))], ['collections'], 'No new duplicate navigation targets may be introduced.');
for (const id of navIds) assert.ok(panelIds.includes('tab-' + id), 'Navigation target must resolve to a panel: ' + id);

const start = source.indexOf('function bokanProdMapProformaRow(r)');
const end = source.indexOf('async function bokanProdLoadIssuer(key)', start);
assert.ok(start >= 0 && end > start, 'Proforma row mapper and issuer loader must exist.');
const mapper = source.slice(start, end);
assert.match(mapper, /vatPct:Number\(r\.vat_rate\?\?15\)/, 'Saved Proforma VAT rate must round-trip into the editor.');
assert.match(mapper, /companyName:r\.company\?\.name/, 'Company label must use the live companies.name shape.');

const issuerStart = source.indexOf('async function bokanProdLoadIssuer(key)');
const issuerEnd = source.indexOf('async function bokanProdRefreshIssuer', issuerStart);
const issuer = source.slice(issuerStart, issuerEnd);
assert.match(issuer, /from\('companies'\)\.select\('id,code,name,is_active'\)/, 'Issuer lookup must use the live company master columns.');
assert.match(issuer, /from\('company_proforma_settings'\)/, 'Issuer-specific fields must come from the additive settings table.');
assert.match(issuer, /from\('company_bank_accounts'\)[\s\S]*?eq\('company_id',companyRow\.id\)/, 'Bank accounts must be scoped by company UUID.');
assert.doesNotMatch(issuer, /select\([^)]*(legal_name|proforma_title_color)|companyRow\?\.legal_name|\.eq\('company_code',key\)/, 'Issuer bridge must not query nonexistent company columns or scope bank rows by code.');

assert.match(source, /rpc\('bokan_save_company_proforma_settings'/, 'Issuer TIN/contact edits must use the authorized RPC.');
assert.match(source, /async function bokanProdSaveBanks\(key,banks\)\{ if\(bokanProdEnabled\(\)\) throw new Error\('Bank account changes are temporarily disabled/, 'Production bank-account changes must fail closed until an audited RPC exists.');
assert.match(source, /if \(companyId\) row\.company_id = companyId/, 'Custom terms must include the live UUID company foreign key in production.');
assert.match(sql, /create table if not exists public\.company_proforma_settings[\s\S]*?company_id uuid primary key references public\.companies\(id\)/, 'Settings table must use the live UUID company key.');
assert.match(sql, /create table if not exists public\.company_bank_accounts[\s\S]*?company_id uuid not null references public\.companies\(id\)/, 'Bank accounts must reference the live UUID company master.');
assert.match(sql, /create table if not exists public\.proformas[\s\S]*?company_id uuid not null references public\.companies\(id\)/, 'Proformas must reference the live UUID company master.');
assert.match(sql, /public\.company_memberships[\s\S]*?m\.company_id = v_company_id and m\.user_id = v_uid and m\.is_active/, 'Write RPCs must require an active company membership.');
assert.match(sql, /private\.has_company_membership\(company_id\)/, 'Read policies must scope rows to active company membership.');
assert.match(sql, /private\.has_company_membership\(company_id\) and exists \(select 1 from public\.companies c where c\.id = company_id and c\.is_active\)/, 'Read policies must also reject inactive companies.');
assert.match(sql, /create or replace function public\.bokan_save_proforma[\s\S]*?security invoker[\s\S]*?select private\.bokan_save_proforma/, 'Public Proforma save must be an invoker wrapper.');
assert.match(sql, /create or replace function public\.bokan_save_company_proforma_settings[\s\S]*?security invoker[\s\S]*?private\.bokan_save_company_proforma_settings/, 'Issuer settings writes must go through the authorized RPC.');
assert.match(sql, /grant select on public\.company_proforma_settings, public\.company_bank_accounts, public\.custom_terms, public\.proformas to authenticated/, 'Client access must be limited to reads plus separately scoped custom-term inserts.');
assert.doesNotMatch(sql, /create table if not exists public\.profiles|create table if not exists public\.companies\s*\(/, 'The candidate must not introduce a competing profiles/company model.');

console.log('PASS: live UUID-company Proforma candidate and full UI bridge contracts are aligned (static checks only).');
