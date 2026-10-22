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
assert.match(config,/SUPABASE_URL\s*:\s*""/,'Supabase URL must remain blank.');
assert.match(config,/SUPABASE_ANON_KEY\s*:\s*""/,'Supabase browser key must remain blank.');
assert.match(html,/Server-backed modules are unavailable\. Sign-in requires the configured application API\./,'Hosted legacy adapter must fail closed.');
console.log('PASS: release candidate has empty fixture collections and disabled production config.');
