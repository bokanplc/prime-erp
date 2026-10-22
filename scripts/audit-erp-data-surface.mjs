#!/usr/bin/env node
/**
 * Review gate for the ERP's direct data-access surface.
 * This is lexical inventory, not a JavaScript parser or authorization proof.
 * Run from repository root: node scripts/audit-erp-data-surface.mjs
 */
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const sourcePath = 'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html';
const entryPath = 'staging/index.html';
const source = readFileSync(sourcePath, 'utf8');
const entry = readFileSync(entryPath, 'utf8');

const expectedTables = [
  'bokan_ap_bills','bokan_ap_payments','bokan_ar_invoices','bokan_ar_receipts',
  'bokan_attendance_records','bokan_customer_activities','bokan_customer_assignments',
  'bokan_customers','bokan_delivery_orders','bokan_employees','bokan_fiscal_periods',
  'bokan_journal_entries','bokan_leave_requests','bokan_payroll_approvals',
  'bokan_payroll_lines','bokan_payroll_runs','bokan_performance_reviews',
  'bokan_sales_opportunities','bokan_salespeople','bokan_shipments','companies',
  'company_bank_accounts','custom_terms','customer_billings','customer_logs','customers',
  'disciplinary_actions','documents','employees','expenses','leave_requests',
  'notifications','per_diem_requests','performance_reviews','profiles','proformas',
  'sales_targets','stock_entries','stock_ledger','trip_plans','visit_reports'
].sort();

assert.equal(entry, source, 'Staging entry point drifted from the reviewed source; review and sync both files.');

const tables = [...source.matchAll(/\.from\(\s*['"]([a-z][a-z0-9_]*)['"]\s*\)/g)]
  .map(match => match[1]);
const actualTables = [...new Set(tables)].sort();
const addedTables = actualTables.filter(table => !expectedTables.includes(table));
const removedTables = expectedTables.filter(table => !actualTables.includes(table));

if (addedTables.length || removedTables.length) {
  console.error('Direct Supabase table surface changed. Review the data contract and update this baseline intentionally.');
  if (addedTables.length) console.error('New table references: ' + addedTables.join(', '));
  if (removedTables.length) console.error('Removed table references: ' + removedTables.join(', '));
  process.exit(1);
}

const operations = {};
for (const match of source.matchAll(/\.from\(\s*['"]([a-z][a-z0-9_]*)['"]\s*\)\s*\.\s*(select|insert|update|upsert|delete)\s*\(/g)) {
  const table = match[1], operation = match[2];
  operations[operation] = (operations[operation] || 0) + 1;
}
const rpcs = [...new Set([...source.matchAll(/\.rpc\(\s*['"]([^'"]+)['"]/g)].map(match => match[1]))].sort();
const buckets = [...new Set([...source.matchAll(/\.storage\.from\(\s*['"]([^'"]+)['"]/g)].map(match => match[1]))].sort();
const apiPaths = [...new Set([...source.matchAll(/['"`]\/(api\/[a-zA-Z0-9_\/:*.-]+)/g)].map(match => '/' + match[1]))].sort();
const localStorageKeys = [...new Set([...source.matchAll(/localStorage\.(?:getItem|setItem|removeItem)\(\s*['"]([^'"]+)['"]/g)].map(match => match[1]))].sort();
const selectStarCount = [...source.matchAll(/\.select\(\s*['"]\*['"]\s*\)/g)].length;
const publicStorageHelperCount = [...source.matchAll(/getPublicUrl\s*\(/g)].length;
const securityDefinerMentionCount = [...source.matchAll(/security\s+definer/gi)].length;

console.log('BOKAN ERP direct data-surface inventory');
console.log('Direct literal table names: ' + actualTables.length);
console.log('Operation call counts: ' + JSON.stringify(operations));
console.log('RPCs: ' + (rpcs.join(', ') || '(none detected)'));
console.log('Storage buckets: ' + (buckets.join(', ') || '(none detected)'));
console.log('Legacy API paths detected: ' + apiPaths.length);
console.log('Literal localStorage keys detected: ' + localStorageKeys.length);
console.log('select("*") call count: ' + selectStarCount);
console.log('getPublicUrl call count: ' + publicStorageHelperCount);
console.log('Security-definer text mentions: ' + securityDefinerMentionCount);
console.log('Known production blockers are reported for review, not automatically approved.');
console.log('PASS: direct table-name baseline and staging/source parity are unchanged.');
