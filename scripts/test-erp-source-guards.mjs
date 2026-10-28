#!/usr/bin/env node
/**
 * Regression checks for the production authentication startup guard.
 * Run from repository root: node scripts/test-erp-source-guards.mjs
 */
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const source = readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const entry = readFileSync('staging/index.html', 'utf8');
const config = readFileSync('staging/config/config.js', 'utf8');

assert.equal(entry, source, 'staging/index.html must match the reviewed source exactly.');
assert.match(config, /PRODUCTION_MODE\s*:\s*false/, 'Production mode must remain disabled until release approval.');
assert.match(config, /FULL_ERP_DATA_READY\s*:\s*false/, 'Full ERP data readiness must remain disabled until all modules are migrated and tested.');
assert.match(config, /ENABLED_PRODUCTION_TABS\s*:\s*\[\]/, 'No production module may be enabled before explicit review.');
assert.match(config, /SUPABASE_URL\s*:\s*""/, 'Supabase URL placeholder must remain blank in the committed template.');
assert.match(config, /SUPABASE_ANON_KEY\s*:\s*""/, 'Supabase browser key placeholder must remain blank in the committed template.');

const bootStart = source.indexOf('async function boot()');
const bootEnd = source.indexOf('function showLanding', bootStart);
assert.ok(bootStart >= 0 && bootEnd > bootStart, 'Main boot function must exist.');
const boot = source.slice(bootStart, bootEnd);
const guardIndex = boot.indexOf('const demoReview = config.DEMO_REVIEW_MODE === true && config.PRODUCTION_MODE !== true;');
const hostGuardIndex = boot.indexOf('if ((!localPreview && !demoReview) || config.PRODUCTION_MODE === true)');
const previewIdentityIndex = boot.indexOf("currentUser = { id: 'preview-admin'");
assert.ok(guardIndex >= 0 && hostGuardIndex > guardIndex, 'Hosted preview identity must require explicit demo mode and production must remain blocked.');
assert.ok(previewIdentityIndex > guardIndex, 'Preview identity must only be assigned after the local-preview guard.');

const autoStart = source.indexOf('// Start local preview only on file/localhost');
const autoEnd = source.indexOf('</script>', autoStart);
assert.ok(autoStart >= 0 && autoEnd > autoStart, 'Boot error handler must exist.');
const autoBoot = source.slice(autoStart, autoEnd);
assert.match(autoBoot, /app-view['"]\)\?\.classList\.add\(['"]hidden['"]\)/, 'Startup failure must hide the app.');
assert.doesNotMatch(autoBoot, /app-view['"]\)\?\.classList\.remove\(['"]hidden['"]\)/, 'Startup failure must never reveal the app.');

assert.match(source, /window\.BOKAN_REVIEWED_PRODUCTION_TABS = Object\.freeze\(\[\]\)/, 'No module is currently approved for production.');
assert.match(source, /window\.BOKAN_HAS_REVIEWED_PRODUCTION_TAB = function\(cfg\)/, 'Production activation must require an explicit reviewed module.');
assert.match(source, /const _bokanProdConfigured = !!\(_bokanCfg\.PRODUCTION_MODE===true && _bokanCfg\.FULL_ERP_DATA_READY===true && window\.BOKAN_HAS_REVIEWED_PRODUCTION_TAB\(_bokanCfg\) && window\.supabase/, 'Core Supabase client must require full readiness and a reviewed enabled module.');
assert.match(source, /return \(map\[role\]\|\|\[\]\)\.filter\(tab=>enabled\.has\(tab\)\)/, 'Production navigation must intersect role permissions with the reviewed module allowlist.');
assert.match(source, /if \(_bokanProdConfigured\) window\.sb = sb;/, 'Configured real Supabase client must be exposed to production bridge modules.');
assert.match(source, /if \(_bokanProdConfigured\) \{\s*alert\('Document uploads are temporarily disabled/, 'Production document uploads must remain blocked until private storage is implemented.');
assert.match(source, /Document downloads are temporarily disabled until private storage and authorized downloads are configured/, 'Production document listing/download links must remain blocked until private signed downloads are implemented.');
assert.match(source, /Production role changes are disabled until audited Supabase Auth user provisioning and company-membership management are implemented/, 'Production role changes must remain blocked until trusted provisioning exists.');
assert.match(source, /Only an authorized administrator or accounting user can request issuer TIN changes/, 'Production issuer TIN edits must be role-restricted.');
assert.match(source, /Only an authorized administrator or accounting user can request issuer contact changes/, 'Production issuer contact edits must be role-restricted.');
assert.match(source, /async function bokanProdSaveBanks\(key,banks\)\{ if\(bokanProdEnabled\(\)\) throw new Error\('Bank account changes are temporarily disabled until an atomic, audited database workflow is configured\.'/, 'Production bank-account replacement must remain blocked until atomic audited writes exist.');
assert.match(source, /if\(bokanProdEnabled\(\)\)\{row\.querySelectorAll\('input'\)\.forEach\(el=>\{el\.readOnly=true/, 'Production proforma bank details must be read-only to prevent edited bank-account snapshots.');
assert.match(source, /https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2\.118\.0/, 'Supabase browser SDK must be pinned to an exact reviewed version.');
assert.match(source, /escapeHtml\(row\.next_action_type \|\| 'Follow-up'\)/, 'CRM follow-up activity type must be HTML-escaped before rendering.');
assert.match(source, /escapeHtml\(row\.customers\?\.customer_name \|\| ''\)/, 'CRM customer name must be HTML-escaped before rendering.');
assert.match(source, /escapeHtml\(row\.next_action_date \|\| ''\)/, 'CRM follow-up date must be HTML-escaped before rendering.');
assert.match(source, /id="bokan-v61-production-auth"/, 'Production authentication bridge must exist.');
assert.match(source, /async function deleteProforma\(id\) \{ if \(_bokanProdConfigured\) \{ alert\('Proforma deletion is disabled in production until an audited void workflow is implemented\.'\); return; \}/, 'Production proforma deletion must remain blocked until an audited void workflow exists.');
assert.match(source, /async function bokanProdSaveProforma\(payload,existing\)/, 'Production proforma save must accept existing-version context.');
assert.match(source, /db\.rpc\('bokan_save_proforma'/, 'Production proforma save must use the atomic database RPC.');
assert.doesNotMatch(source, /bokanProdNextProformaNumber|bokan_next_proforma_number/, 'Production must not use the separate candidate-number RPC.');
assert.match(source, /productionSavedRecord=await bokanProdSaveProforma\(\{[\s\S]{0,650}?withholdingThreshold,items,terms\s*\}, existing\);/, 'Production proforma revision must pass existing record to the atomic save function.');
assert.match(source, /productionSavedRecord=await bokanProdSaveProforma\(/, 'Production save result must be captured.');
assert.match(source, /const savedRecord=productionSavedRecord\|\|\{id:existing\?\.id/, 'Production persistence must use the database-returned ID/version rather than a synthetic local ID.');
assert.match(source, /id="bokan-v67-hosted-fail-closed"/, 'Hosted fail-closed guard must exist.');
assert.match(source, /cfg\.FULL_ERP_DATA_READY\s*===\s*true/, 'Hosted access must require explicit full-ERP data readiness.');
assert.match(source, /const configured=!!\(cfg\.PRODUCTION_MODE===true && cfg\.FULL_ERP_DATA_READY===true && typeof window\.BOKAN_HAS_REVIEWED_PRODUCTION_TAB==='function' && window\.BOKAN_HAS_REVIEWED_PRODUCTION_TAB\(cfg\)/, 'Supabase auth bridge must require a reviewed enabled module.');
assert.match(source, /const configured = !!\(cfg\.PRODUCTION_MODE === true && cfg\.FULL_ERP_DATA_READY === true && typeof window\.BOKAN_HAS_REVIEWED_PRODUCTION_TAB === 'function' && window\.BOKAN_HAS_REVIEWED_PRODUCTION_TAB\(cfg\)/, 'Hosted fail-closed guard must require a reviewed enabled module.');
assert.match(source, /const demoReview = cfg\.DEMO_REVIEW_MODE === true && cfg\.PRODUCTION_MODE !== true;[\s\S]{0,500}if \(localPreview \|\| demoReview \|\| configured\) return;/, 'Hosted guard must allow only the explicit sample-data staging review mode while production remains fail-closed.');
assert.match(source, /const localPreview=location\.protocol==='file:'\|\|\['localhost','127\.0\.0\.1','::1'\]\.includes\(location\.hostname\); const cfg=window\.BOKAN_CONFIG\|\|\{\}; const demoReview=cfg\.DEMO_REVIEW_MODE===true && cfg\.PRODUCTION_MODE!==true; const DEV_BYPASS=localPreview\|\|demoReview;/, 'Legacy API bypass must be restricted to local preview or the explicit staging-only demo review mode.');
assert.doesNotMatch(source, /#prime-prod-gate\{display:none!important\}/, 'Production gate must not be force-hidden by CSS.');
assert.match(source, /Server-backed modules are unavailable\. Sign-in requires the configured application API\./, 'Hosted legacy adapter failure must remain fail-closed.');
assert.match(source, /if\(window\.BOKAN_PRODUCTION_AUTH\?\.enabled\)\{gate\.style\.display='none';top\.style\.display='none';return;\}/, 'Supabase Auth must replace the legacy API login overlay when configured.');
assert.match(source, /const productionAllowed = window\.BOKAN_PRODUCTION_AUTH\?\.enabled && window\.__BOKAN_PROD_ALLOWED_TABS instanceof Set/, 'Production navigation must use the authenticated role allowlist.');
assert.match(source, /sales_manager:\['sales','saleshub','saleslifecycle','salescalllog','report','salestargets','proformarequest','proforma'/, 'Sales managers must be allowed to create proformas.');
assert.match(source, /sales:\['sales','saleshub','saleslifecycle','salescalllog','salestargets','tripcost','visitreport','proformarequest','proforma'/, 'Sales users must be allowed to create proformas.');

console.log('PASS: BOKAN ERP source startup guards and staging entry-point parity.');
