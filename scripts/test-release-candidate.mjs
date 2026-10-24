#!/usr/bin/env node
/** Verify that the sanitized release candidate is generated and contains no known fixture collections. */
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const html=readFileSync('staging/release/index.html','utf8');
const config=readFileSync('staging/release/config/config.js','utf8');
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
assert.match(html,/const docs=\\[\\]/,'Release candidate must not ship sample document sequence numbers.');
assert.doesNotMatch(html,/Preview Admin|Supplier payment approval|Sales discount exception|doc:'INV-1001',type:'AR Invoice'|name:'Derej'|name:'Yohannes'/,'Release candidate must not ship sample approvals, audit actors, transactions, or salespeople.');
assert.ok(!html.includes('preview-admin')&&!html.includes('preview@primegroup.local'),'Release candidate must not ship a preview administrator identity.');
assert.doesNotMatch(html,/getPublicUrl\s*\(/,'Release candidate must not generate public document URLs.');
assert.match(html,/Document uploads are temporarily disabled until private document storage and authorized downloads are configured/,'Production document uploads must remain blocked.');
assert.match(html,/Document downloads are temporarily disabled until private storage and authorized downloads are configured/,'Release candidate must block production document links.');
assert.doesNotMatch(html,/admin@preview/,'Release candidate must not ship the preview-admin email identity.');
const phoneFieldCount=[...html.matchAll(/\bphone\s*:\s*['"][^'"]{6,}['"]/gi)].length;
assert.ok(phoneFieldCount<=2,'Unexpected hard-coded phone fields found; only the two issuer contact fields are currently allowed.');
const emailLiteralCount=[...html.matchAll(/['"][A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}['"]/gi)].length;
assert.equal(emailLiteralCount,0,'Release candidate must not contain hard-coded email addresses.');
console.log('PASS: release candidate has empty fixture collections and disabled production config.');
