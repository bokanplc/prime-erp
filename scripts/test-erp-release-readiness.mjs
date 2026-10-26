#!/usr/bin/env node
import { mkdtempSync, mkdirSync, cpSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';

const root = mkdtempSync(join(tmpdir(),'bokan-release-gate-'));
const files = [
  'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html',
  'staging/index.html',
  'staging/config/config.js',
  'docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql',
  'scripts/audit-erp-release-readiness.mjs',
  'scripts/build-release-candidate.mjs'
];
try {
  for (const file of files) {
    const destination = join(root,file);
    mkdirSync(dirname(destination),{recursive:true});
    cpSync(file,destination);
  }
  const configPath=join(root,'staging/config/config.js');
  const config=readFileSync(configPath,'utf8');
  assert.match(config,/PRODUCTION_MODE:\s*false/);
  assert.match(config,/FULL_ERP_DATA_READY:\s*false/);
  assert.match(config,/ENABLED_PRODUCTION_TABS:\s*\[\]/);
  assert.match(config,/DEMO_REVIEW_MODE:\s*true/,'Staging must explicitly identify its demo-only review mode.');

  const disabledOutput=execFileSync(process.execPath,[join(root,'scripts/audit-erp-release-readiness.mjs')],{cwd:root,encoding:'utf8'});
  assert.match(disabledOutput,/STOP-SHIP:/,'Readiness audit should report blockers while disabled.');
  assert.match(disabledOutput,/Tables still missing schema: 51/,'Readiness audit must detect the current incomplete schema.');
  assert.match(disabledOutput,/Known raw HTML sink patterns remaining: 0/,'The tracked raw HTML sink patterns must be escaped before the readiness report can pass that check.');
  assert.match(disabledOutput,/PASS: production remains disabled/,'Disabled candidate should be reported safely.');

  writeFileSync(configPath,config.replace('ENABLED_PRODUCTION_TABS: []',"ENABLED_PRODUCTION_TABS: ['proforma']"));
  let unreviewedTabRejected=false;
  try {
    execFileSync(process.execPath,[join(root,'scripts/build-release-candidate.mjs')],{cwd:root,encoding:'utf8',stdio:'pipe'});
  } catch (error) {
    unreviewedTabRejected=error.status===1 && String(error.stderr||'').includes('No production tabs may be enabled');
  }
  assert.ok(unreviewedTabRejected,'The release builder must reject a config-enabled tab that has not been source-reviewed.');
  writeFileSync(configPath,config);

  writeFileSync(configPath,config.replace('PRODUCTION_MODE: false','PRODUCTION_MODE: true'));
  let rejected=false;
  try {
    execFileSync(process.execPath,[join(root,'scripts/audit-erp-release-readiness.mjs')],{cwd:root,encoding:'utf8',stdio:'pipe'});
  } catch (error) {
    rejected=error.status===1 && String(error.stderr||'').includes('FAIL: production/full-data mode cannot be enabled');
  }
  assert.ok(rejected,'The release gate must fail when production mode is enabled while schema/API blockers remain.');
  console.log('PASS: full-ERP release gate rejects premature production enablement and unreviewed module tabs.');
} finally {
  rmSync(root,{recursive:true,force:true});
}
