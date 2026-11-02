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
  'supabase/candidates/live_company_proforma.sql',
  'supabase/baselines/live_company_core_2026-10-31.sql',
  'scripts/audit-erp-release-readiness.mjs',
  'scripts/build-release-candidate.mjs',
  'wrangler.jsonc'
];
try {
  for (const file of files) {
    const destination = join(root,file);
    mkdirSync(dirname(destination),{recursive:true});
    cpSync(file,destination);
  }
  cpSync('supabase/migrations',join(root,'supabase/migrations'),{recursive:true});
  cpSync('supabase/candidates',join(root,'supabase/candidates'),{recursive:true});
  const source=readFileSync(join(root,'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html'),'utf8');
  const entry=readFileSync(join(root,'staging/index.html'),'utf8');
  assert.equal(entry,source,'The deployable staging entry must remain identical to the full V6.7 source.');
  assert.match(source,/from\('profiles'\)[\s\S]{0,180}\.eq\('company_id',companyId\)[\s\S]{0,120}\.in\('id',userIds\)/,
    'CRM representative names must be resolved only from profiles in the active company.');
  assert.match(source,/profile\?\.full_name[\s\S]{0,100}profile\?\.email[\s\S]{0,100}'Sales team member'/,
    'CRM assignment lists must use a safe display-name fallback when a profile name is missing.');
  assert.match(source,/async function addActivity\(payload\)[\s\S]{0,220}actor_user_id:user\.id[\s\S]{0,100}assigned_user_id\)row\.assigned_user_id=user\.id/,
    'CRM activity inserts must set the authenticated actor required by the live RLS policy.');
  const wranglerConfig=JSON.parse(readFileSync(join(root,'wrangler.jsonc'),'utf8'));
  assert.equal(wranglerConfig.name,'prime-erp','Wrangler must target the connected Worker name.');
  assert.equal(wranglerConfig.assets.directory,'./dist/release','Workers Static Assets must serve only generated release output.');
  const configPath=join(root,'staging/config/config.js');
  const config=readFileSync(configPath,'utf8');
  assert.match(config,/PRODUCTION_MODE:\s*false/);
  assert.match(config,/FULL_ERP_DATA_READY:\s*false/);
  assert.match(config,/ENABLED_PRODUCTION_TABS:\s*\[\]/);
  assert.match(config,/DEMO_REVIEW_MODE:\s*true/,'Staging must explicitly identify its demo-only review mode.');

  const reviewBuild=execFileSync(process.execPath,[join(root,'scripts/build-release-candidate.mjs')],{cwd:root,encoding:'utf8',env:{...process.env,WORKERS_CI_BRANCH:'deploy/secure-staging'}});
  const reviewHtml=readFileSync(join(root,'dist/release/index.html'),'utf8');
  const reviewConfig=readFileSync(join(root,'dist/release/config/config.js'),'utf8');
  const reviewHeaders=readFileSync(join(root,'dist/release/_headers'),'utf8');
  const fullReviewSource=readFileSync(join(root,'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html'),'utf8');
  const reviewBanner='PREVIEW ONLY — SAMPLE DATA — CHANGES ARE TEMPORARY AND ARE NOT SAVED TO BLACKROCK BUSINESS RECORDS';
  assert.ok(reviewHtml.includes(reviewBanner),'Staging review build must display a prominent preview-only warning.');
  const expectedReviewSource=fullReviewSource.replace(/<body([^>]*)>/i,'<body$1><div role="status" aria-live="polite" style="position:sticky;top:0;z-index:99999;background:#7c2d12;color:#fff;text-align:center;padding:9px 14px;font:700 12px/1.4 Arial,sans-serif;letter-spacing:.02em">'+reviewBanner+'</div>');
  assert.equal(reviewHtml,expectedReviewSource,'Staging review build must otherwise retain the complete V6.7 review source.');
  assert.match(reviewConfig,/DEMO_REVIEW_MODE:\s*true/,'Staging preview must enable demo mode.');
  assert.match(reviewHeaders,/X-Robots-Tag: noindex, nofollow/,'Staging preview must discourage search indexing.');
  assert.match(reviewBuild,/full V6\.7 preview-only interface/,'Staging branch should produce the full V6.7 preview artifact.');
  const pagesReviewBuild=execFileSync(process.execPath,[join(root,'scripts/build-release-candidate.mjs')],{cwd:root,encoding:'utf8',env:{...process.env,CF_PAGES_BRANCH:'deploy/secure-staging'}});
  assert.match(pagesReviewBuild,/full V6\.7 preview-only interface/,'Pages branch selector remains supported for compatibility.');
  const disabledOutput=execFileSync(process.execPath,[join(root,'scripts/audit-erp-release-readiness.mjs')],{cwd:root,encoding:'utf8'});
  assert.match(disabledOutput,/No static completeness blockers detected by this limited inventory/,'Static inventory is clear but does not approve runtime release.');
  assert.match(disabledOutput,/Referenced tables lacking source-controlled DDL: 0/,'The live core baseline and source-controlled views must cover every referenced table definition; missing original migration bodies remain documented separately.');
  assert.match(disabledOutput,/Supabase-native production authentication: present/,'The reviewed source includes Supabase-native authentication and company membership checks.');
  assert.match(disabledOutput,/Missing backend dependencies: \(none\)/,'The legacy API adapter is bypassed when Supabase production auth is enabled.');
  assert.match(disabledOutput,/Known raw HTML sink patterns remaining: 0/,'The tracked raw HTML sink patterns must be escaped before the readiness report can pass that check.');
  assert.match(disabledOutput,/runtime.*acceptance is still required/,'Static completeness must not be confused with runtime release approval.');
  let prematureProductionRejected=false;
  try {
    execFileSync(process.execPath,[join(root,'scripts/build-release-candidate.mjs')],{
      cwd:root,encoding:'utf8',stdio:'pipe',
      env:{...process.env,VERCEL_GIT_COMMIT_REF:'main',WORKERS_CI_BRANCH:'',CF_PAGES_BRANCH:'',
        BOKAN_PRODUCTION_MODE:'true',BOKAN_FULL_ERP_DATA_READY:'true',
        BOKAN_SUPABASE_URL:'https://example.supabase.co',
        BOKAN_SUPABASE_ANON_KEY:'test-publishable-key-for-guard-check',
        BOKAN_ENABLED_PRODUCTION_TABS:'sales'}
    });
  } catch (error) {
    prematureProductionRejected=error.status===1 && String(error.stderr||'').includes('Production build requested a module that has not been source-reviewed.');
  }
  assert.ok(prematureProductionRejected,'Production env flags must not bypass the source-reviewed module allowlist.');


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
