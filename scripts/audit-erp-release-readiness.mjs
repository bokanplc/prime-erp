#!/usr/bin/env node
/**
 * Full-ERP readiness gate.
 * This report intentionally exits successfully while the app is kept disabled,
 * but fails if production/full-data mode is enabled while the source still has
 * unimplemented tables or the legacy API contract is missing.
 */
import { readFileSync, existsSync } from 'node:fs';
import assert from 'node:assert/strict';

const source = readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html','utf8');
const entry = readFileSync('staging/index.html','utf8');
const config = readFileSync('staging/config/config.js','utf8');
const schema = readFileSync('docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql','utf8');
assert.equal(entry,source,'Staging entry point must match the reviewed source.');

const direct = [...new Set([...source.matchAll(/\.from\(\s*['"]([a-z][a-z0-9_]*)['"]\s*\)/g)].map(m=>m[1]))];
const helper = [...new Set([...source.matchAll(/\b(?:insert|update|q|count)\s*\(\s*['"]([a-z][a-z0-9_]*)['"]/g)].map(m=>m[1]).filter(t=>t.startsWith('bokan_')))];
const referenced = [...new Set([...direct,...helper])].sort();
const defined = [...new Set([...schema.matchAll(/create\s+table\s+(?:if\s+not\s+exists\s+)?public\.([a-z][a-z0-9_]*)/gi)].map(m=>m[1]))].sort();
const missing = referenced.filter(table=>!defined.includes(table));

const requiredApiFileGroups = [
  ['login',['functions/api/auth/login.js']],
  ['change-password',['functions/api/auth/change-password.js']],
  ['logout',['functions/api/auth/logout.js']],
  ['bootstrap',['functions/api/bootstrap.js']],
  ['store',['functions/api/store/[[path]].js','functions/api/store/[key].js']]
];
const missingApiGroups = requiredApiFileGroups
  .filter(([,paths])=>!paths.some(path=>existsSync(path)))
  .map(([name])=>name);
const apiBackendPresent = missingApiGroups.length === 0;
const rawHtmlSinkPatterns = [
  ['notification messages',/\.innerHTML\s*=\s*data\.map\(n\s*=>\s*`[\s\S]{0,500}\$\{n\.message\}/],
  ['customer dropdown values',/\.innerHTML\s*=\s*data\.map\(c\s*=>\s*`<option value="\$\{c\.customer_name\}/],
  ['stock item names',/\.innerHTML\s*=\s*stockData\.map\(row\s*=>\s*`[\s\S]{0,500}\$\{row\.item_name\}/],
  ['CRM overdue customer names',/\.innerHTML\s*=\s*overdue\.map\(o\s*=>\s*`[\s\S]{0,500}\$\{o\.customer\.customer_name\}/],
  ['customer activity actor names',/\.innerHTML\s*=\s*logs\.map\(log\s*=>\s*`[\s\S]{0,500}\$\{nameById\[log\.sales_rep\]/],
  ['visit report names',/\.innerHTML\s*=\s*visitReportData\.map\(row\s*=>\s*`[\s\S]{0,500}\$\{row\.employee_name\}/],
  ['role panel names',/\.innerHTML\s*=\s*data\.map\(u\s*=>\s*`[\s\S]{0,400}\$\{u\.full_name\}/],
  ['document titles and URLs',/\.innerHTML\s*=\s*data\.map\(d\s*=>\s*`[\s\S]{0,500}href="\$\{d\.file_url\}"[\s\S]{0,150}\$\{d\.title\}/],
  ['billing customer names',/\.innerHTML\s*=\s*billingData\.map\(row\s*=>\s*`[\s\S]{0,500}\$\{row\.customer_name\}/],
  ['employee names',/\.innerHTML\s*=\s*employeeData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.full_name\}/],
  ['leave request names',/\.innerHTML\s*=\s*leaveData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.employee_name\}/],
  ['performance review names',/\.innerHTML\s*=\s*perfData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.employee_name\}/],
  ['disciplinary action names',/\.innerHTML\s*=\s*discData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.employee_name\}/],
  ['alert text',/\.innerHTML\s*=\s*alerts\.map\(a\s*=>\s*`[\s\S]{0,300}\$\{a\.text\}/],
  ['employee autocomplete values',/\$\{e\.full_name\}/],
  ['CRM reassignment profile names',/\$\{p\.full_name\}/],
  ['CRM contact values',/\$\{c\.contact_person\s*\|\|\s*'—'\}/],
  ['CRM location values',/\$\{c\.location\s*\|\|\s*'—'\}/],
  ['CRM assigned salesperson names',/\$\{nameById\[c\.assigned_rep\]\s*\|\|\s*'Unassigned'\}/],
  ['CRM status values',/\$\{c\.current_status\s*\|\|\s*''\}/],
  ['CRM inline customer-name handler',/onclick="document\.getElementById\('cust-name'\)\.value='\$\{c\.customer_name\.replace/],
  ['CRM escalation reasons',/\$\{log\.escalate_reason\s*\|\|\s*''\}/],
  ['weekly CRM customer names',/\$\{row\.customers\?\.customer_name\s*\|\|\s*''\}/],
  ['weekly CRM notes',/\$\{row\.notes\s*\|\|\s*''\}/],
  ['stock ledger quantity fields',/\$\{row\.factory_qty\s*\|\|\s*0\}/],
  ['stock ledger note fields',/\$\{row\.notes\s*\?\s*'· '\s*\+\s*row\.notes\s*:\s*''\}/],
  ['stock overview entry type',/\$\{row\.entry_type\}/],
  ['sales target employee names',/\$\{r\.employee_name\}/],
  ['leave status text',/\$\{row\.status\|\|'Pending'\}/],
  ['delivery location',/\$\{d\.location \|\| 'Delivery'\}/],
  ['delivery vehicle',/\$\{d\.vehicle \? ' — ' \+ d\.vehicle : ''\}/],
  ['delivery product type',/\$\{i\.product_type\}/],
  ['delivery quality',/\$\{i\.quality \|\| '-'\}/],
  ['delivery quantity',/\$\{i\.qty\}/],
  ['delivery unit price',/\$\{i\.unit_price\.toLocaleString\(\)\}/],
  ['delivery line total',/\$\{\(i\.qty\*i\.unit_price\)\.toLocaleString\(\)\}/],
  ['proforma list number',/\$\{p\.proforma_no\}/],
  ['proforma list customer',/\$\{p\.customer_name\}/],
  ['user role label',/\$\{u\.role\}/],
  ['stock seller label for Kolfe',/\$\{salesKolfe \? \(row\.sold_by \|\| '-'\) : '-'\}/],
  ['stock seller label for Meskel Flower',/\$\{salesMes \? \(row\.sold_by \|\| '-'\) : '-'\}/],
  ['local proforma version',/\$\{r\.version\|\|1\}/],
  ['local proforma VAT rate',/\$\{r\.vatPct\}/],
  ['local proforma item quantity attribute',/\$\{data\.qty \?\? ''\}/],
  ['local proforma unit price attribute',/\$\{data\.unit_price \?\? ''\}/],
  ['withholding form date',/\$\{i\.date \|\| ''\}/],
  ['withholding invoice number',/\$\{i\.inv \|\| ''\}/],
  ['withholding description',/\$\{i\.desc \|\| ''\}/],
  ['withholding gross amount',/\$\{i\.gross\.toLocaleString\(\)\}/],
  ['withholding rate',/\$\{i\.rate\}/],
  ['withholding computed tax',/\$\{\(i\.gross\*i\.rate\/100\)\.toLocaleString\(\)\}/],
  ['withholding certificate',/\$\{i\.cert \|\| ''\}/],
  ['HR department name',/\$\{d\}<\/span><span class="value">\$\{c\}/],
  ['stock location grouping',/\.innerHTML\s*=\s*Object\.entries\(byLoc\)[\s\S]{0,500}\$\{loc\}<\/span>/],
  ['CRM pipeline status',/\.innerHTML\s*=\s*Object\.keys\(pipelineCounts\)[\s\S]{0,300}\$\{s\}<\/span><span class="font-semibold">\$\{c\}/],
  ['department landing labels',/grid\.innerHTML\s*=\s*available\.map\(d => `[^`]*\$\{d\.label\}[^`]*\$\{d\.desc\}/],
  ['stock edit handler IDs',/stockData\.map\(row => `[^`]*onclick="editStock\('\$\{row\.id\}'\)"/],
  ['stock delete handler IDs',/stockData\.map\(row => `[^`]*onclick="deleteStock\('\$\{row\.id\}'\)"/],
  ['close-control area rows',/v34-area-rows'\)\.innerHTML=a\.map\(x=>`[^`]*\$\{x\.area\}/],
  ['close-control statement rows',/v34-statement-rows'\)\.innerHTML=s\.map\(x=>`[^`]*\$\{x\.statement\}/],
  ['posting register document fields',/v35-rows'\)\.innerHTML=p\.map\(x=>`[^`]*\$\{x\.doc\}/],
  ['posting register status',/v35-rows'\)\.innerHTML=p\.map\(x=>`[^`]*\$\{x\.status\}/],
  ['supply tower inbound fields',/innerHTML=inbound\.map\(x=>`[^`]*\$\{x\.purchasing_entity\}/],
  ['supply tower delivery fields',/innerHTML=deliveries\.map\(x=>`[^`]*\$\{x\.customer_id/],
  ['call-log inline IDs',/bokanCallLog\.(?:setRep|setField|openAccount)\(\$\{x\.id\}/],
  ['access-registry inline IDs',/onclick="bokanAccessToggle\('\$\{u\.id\}'\)"/]
];
const rawHtmlSinks = rawHtmlSinkPatterns.filter(([,pattern])=>pattern.test(source)).map(([name])=>name);
const productionMode = /PRODUCTION_MODE\s*:\s*true/.test(config);
const fullDataReady = /FULL_ERP_DATA_READY\s*:\s*true/.test(config);
const enabledTabsMatch = config.match(/ENABLED_PRODUCTION_TABS\s*:\s*\[([^\]]*)\]/);
const enabledTabs = enabledTabsMatch ? [...enabledTabsMatch[1].matchAll(/['\"]([^'\"]+)['\"]/g)].map(m=>m[1]) : [];
const reviewedTabsMatch = source.match(/window\.BOKAN_REVIEWED_PRODUCTION_TABS\s*=\s*Object\.freeze\(\[([^\]]*)\]\)/);
const reviewedTabs = reviewedTabsMatch ? [...reviewedTabsMatch[1].matchAll(/['\"]([^'\"]+)['\"]/g)].map(m=>m[1]) : [];
const unreviewedEnabledTabs = enabledTabs.filter(tab=>!reviewedTabs.includes(tab));
const blockers = [];
if(missing.length) blockers.push('Missing database table definitions ('+missing.length+'/'+referenced.length+'): '+missing.join(', '));
if(!apiBackendPresent) blockers.push('Legacy authenticated /api backend is missing these Cloudflare Pages Functions groups: '+missingApiGroups.join(', ')+'.');
if(rawHtmlSinks.length) blockers.push('Known unescaped data-driven HTML sinks remain: '+rawHtmlSinks.join(', ')+'.');
if(!/SUPABASE_URL\s*:\s*""/.test(config) || !/SUPABASE_ANON_KEY\s*:\s*""/.test(config)) {
  // A configured browser key is not a release approval; the full readiness gate must still be satisfied.
  console.log('INFO: browser Supabase configuration is non-empty; this is not proof of schema or RLS readiness.');
}
if(!/create or replace function public\.bokan_save_proforma/.test(schema)) blockers.push('Trusted proforma save function is missing from the reviewed first-slice schema.');
if(!/enable row level security/i.test(schema)) blockers.push('The schema draft contains no RLS enablement.');
if(!enabledTabsMatch) blockers.push('Production config is missing ENABLED_PRODUCTION_TABS.');
if(unreviewedEnabledTabs.length) blockers.push('Production config enables tabs not approved by source-level module review: '+unreviewedEnabledTabs.join(', ')+'.');
if((productionMode || fullDataReady) && enabledTabs.length===0) blockers.push('Production/full-data mode requires at least one explicitly reviewed production module tab.');

console.log('BOKAN ERP full-release readiness audit');
console.log('Referenced logical database tables: '+referenced.length);
console.log('Tables defined in current first-slice schema: '+defined.length+' ('+defined.join(', ')+')');
console.log('Tables still missing schema: '+missing.length);
console.log('Legacy API endpoint groups missing: '+(missingApiGroups.join(', ')||'(none)'));
console.log('Known raw HTML sink patterns remaining: '+rawHtmlSinks.length+(rawHtmlSinks.length?' ('+rawHtmlSinks.join(', ')+')':''));
console.log('PRODUCTION_MODE: '+productionMode);
console.log('FULL_ERP_DATA_READY: '+fullDataReady);
console.log('Source-reviewed production tabs: '+(reviewedTabs.join(', ')||'(none)'));
console.log('Configured production tabs: '+(enabledTabs.join(', ')||'(none)'));
if(blockers.length) {
  console.log('STOP-SHIP:');
  for(const blocker of blockers) console.log(' - '+blocker);
} else {
  console.log('No static completeness blockers detected by this limited inventory.');
}
if((productionMode || fullDataReady) && blockers.length) {
  console.error('FAIL: production/full-data mode cannot be enabled while stop-ship blockers remain.');
  process.exit(1);
}
if(blockers.length) {
  console.log('PASS: production remains disabled; this is a warning inventory, not release approval.');
} else {
  console.log('PASS: static completeness inventory is clear; runtime/security acceptance is still required.');
}
