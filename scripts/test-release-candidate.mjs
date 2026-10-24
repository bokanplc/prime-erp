#!/usr/bin/env node
/** Verify that the sanitized release candidate is generated and contains no known fixture collections. */
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const html=readFileSync('dist/release/index.html','utf8');
const config=readFileSync('dist/release/config/config.js','utf8');
const headers=readFileSync('dist/release/_headers','utf8');
const expected={
  prime_v40_transactions:'[]',
  bokan_customer_call_log_v2:'[]',
  prime_v30_controls:'{ controls: [], exceptions: [], source: [], due: [] }',
  prime_v32_trace:'[]',
  prime_v33_reconciliation:'{ reconciliations: [], exceptions: [] }',
  prime_v34_close_control:'{ areas: [], statements: [], prerequisite: [] }',
  prime_v35_postings:'{ postings: [] }',
  bokan_access_registry_v2:'[]',
  bokan_supply_tower_v1:'{ inbound: [], deliveries: [] }'
};
for(const [key,literal] of Object.entries(expected)){
  const marker="const KEY='"+key+"'",start=html.indexOf(marker);
  assert.ok(start>=0,'Release candidate must preserve module key: '+key);
  const end=html.indexOf('</script>',start),script=html.slice(start,end),seedAt=script.indexOf('const seed');
  assert.ok(seedAt>=0,'Release candidate must preserve seed declaration: '+key);
  const eq=script.indexOf('=',seedAt);let cursor=eq+1;while(/\s/.test(script[cursor]||''))cursor++;
  const actual=script.slice(cursor).match(/^(?:\[[\s\S]*?\]|\{[\s\S]*?\})/)[0];
  assert.equal(actual,literal,'Release fixture must be empty for '+key);
}
assert.match(config,/PRODUCTION_MODE\s*:\s*false/,'Production mode must remain disabled.');
assert.match(config,/FULL_ERP_DATA_READY\s*:\s*false/,'Full ERP data readiness must remain disabled.');
assert.match(html,/const _bokanProdConfigured = !!\(_bokanCfg\.PRODUCTION_MODE===true && _bokanCfg\.FULL_ERP_DATA_READY===true && window\.supabase/,'Release candidate must retain the full-ERP readiness gate on the core Supabase client.');
assert.match(config,/SUPABASE_URL\s*:\s*""/,'Supabase URL must remain blank.');
assert.match(config,/SUPABASE_ANON_KEY\s*:\s*""/,'Supabase browser key must remain blank.');
assert.match(html,/Server-backed modules are unavailable\. Sign-in requires the configured application API\./,'Hosted legacy adapter must fail closed.');
assert.match(html,/Production configuration is required; demo data and preview sign-in are disabled in this build\./,'Release candidate must use the disabled, non-demo backend stub.');
assert.doesNotMatch(html,/DEMO_USER|store\.customers\.push|store\.employees\.push|store\.profiles\.push|preview@primegroup\.local/,'Release candidate must not ship hard-coded mock users, customer/employee records, or preview email.');
assert.ok(html.includes("const KEY='bokan_sales_hub_v1', RAW=[]"),'Release candidate must empty the separate embedded sales-hub customer list.');
assert.match(html,/const master=\{customers:\[\], suppliers:\[\], products:\[\]\}/,'Release candidate must empty the enterprise master-data fixture.');
assert.match(html,/const stock=\[\]/,'Release candidate must empty the enterprise stock fixture.');
assert.match(html,/const pay=\[\]/,'Release candidate must empty the enterprise payroll fixture.');
assert.doesNotMatch(html,/Sugar Corporation \/ Meti Desta|Habesha Construction PLC|name:'Supplier A'|name:'Employee A',dept:|sku:'PLY-G-18'/,'Release candidate must not ship embedded enterprise customer, supplier, employee, or stock examples.');
assert.match(html,/const seedA=\[\]/,'Release candidate must empty governance approval fixtures.');
assert.match(html,/const seedD=\[\]/,'Release candidate must empty preview audit fixtures.');
assert.match(html,/const recSeed=\[\]/,'Release candidate must empty reconciliation fixtures.');
assert.match(html,/const closeSeed=\[\]/,'Release candidate must empty close-control fixtures.');
assert.match(html,/const seedTx=\[\]/,'Release candidate must empty sample financial transactions.');
assert.match(html,/const seedReps=\[\]/,'Release candidate must empty sample sales representatives.');
assert.match(html,/const docs=\[\]/,'Release candidate must not ship sample document sequence numbers.');
assert.doesNotMatch(html,/Preview Admin|Supplier payment approval|Sales discount exception|doc:'INV-1001',type:'AR Invoice'|name:'Derej'|name:'Yohannes'/,'Release candidate must not ship sample approvals, audit actors, transactions, or salespeople.');
assert.ok(!html.includes('preview-admin')&&!html.includes('preview@primegroup.local'),'Release candidate must not ship a preview administrator identity.');
assert.doesNotMatch(html,/Preview Admin|Preview Admin — admin/,'Release candidate must not display a preview administrator label or audit actor.');
assert.doesNotMatch(html,/getPublicUrl\s*\(/,'Release candidate must not generate public document URLs.');
assert.match(html,/function safeDocumentHref\(value\)[\s\S]{0,450}parsed\.protocol !== 'https:' \|\| parsed\.origin !== expectedOrigin[\s\S]{0,180}\/storage\/v1\/object\/sign\/documents\//,'Release candidate must restrict document links to same-project private signed Storage URLs.');
assert.match(html,/rel="noopener noreferrer"/,'External document tabs must not retain an opener reference.');
assert.match(html,/data-file-path="\$\{escapeHtml\(d\.file_path\)\}"[\s\S]{0,180}deleteRepoFile\(this\.dataset\.docId,this\.dataset\.filePath/,'Document delete actions must pass data through escaped dataset attributes, not inline JavaScript string interpolation.');
assert.match(html,/let _bokanProformaSaveInFlight = false;[\s\S]{0,900}if \(_bokanProformaSaveInFlight\) return;[\s\S]{0,250}_bokanProformaSaveInFlight = true;[\s\S]{0,500}button\.disabled = true;[\s\S]{0,800}finally \{[\s\S]{0,200}_bokanProformaSaveInFlight = false;/,'Release candidate must block duplicate concurrent Proforma saves.');
assert.match(html,/Proforma deletion is disabled in production until an audited void workflow is implemented/,'Production proforma deletion must remain blocked until an audited void workflow exists.');
assert.match(html,/Document uploads are temporarily disabled until private document storage and authorized downloads are configured/,'Production document uploads must remain blocked.');
assert.match(html,/Document downloads are temporarily disabled until private storage and authorized downloads are configured/,'Release candidate must block production document links.');
assert.doesNotMatch(html,/admin@preview/,'Release candidate must not ship the preview-admin email identity.');
const phoneFieldCount=[...html.matchAll(/\bphone\s*:\s*['"][^'"]{6,}['"]/gi)].length;
assert.ok(phoneFieldCount<=2,'Unexpected hard-coded phone fields found; only the two issuer contact fields are currently allowed.');
const emailLiteralCount=[...html.matchAll(/['"][A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}['"]/gi)].length;
assert.equal(emailLiteralCount,0,'Release candidate must not contain hard-coded email addresses.');
assert.match(headers, /X-Content-Type-Options: nosniff/, 'Release candidate must set nosniff.');
assert.match(headers, /X-Frame-Options: DENY/, 'Release candidate must deny framing.');
assert.match(headers, /Referrer-Policy: strict-origin-when-cross-origin/, 'Release candidate must set a referrer policy.');
assert.match(headers, /Permissions-Policy: camera=\(\), microphone=\(\), geolocation=\(\), payment=\(\)/, 'Release candidate must disable unused sensitive browser capabilities.');
console.log('PASS: release candidate has empty fixture collections and disabled production config.');
