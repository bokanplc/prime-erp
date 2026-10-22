#!/usr/bin/env node
/**
 * Static stop-ship audit for BOKAN ERP V6.7.
 *
 * Run from repository root:
 *   node scripts/audit-erp-source.mjs
 *
 * This is a guardrail, not a security test. A clean result does not prove that
 * RLS, Auth, Storage policies, or production workflows are secure.
 */
import { readFileSync, existsSync } from 'node:fs';

const sourcePath = 'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html';
const entryPath = 'staging/index.html';
const configPath = 'staging/config/config.js';
const failures = [];
const warnings = [];

if (!existsSync(sourcePath)) {
  console.error(`STOP: reviewed ERP source is missing: ${sourcePath}`);
  process.exit(2);
}
const source = readFileSync(sourcePath, 'utf8');
if (!existsSync(entryPath)) failures.push(`Deployment entry point is missing: ${entryPath}.`);
const entry = existsSync(entryPath) ? readFileSync(entryPath, 'utf8') : '';
if (entry && entry !== source) failures.push('staging/index.html differs from the reviewed source; synchronize before deployment.');
const config = existsSync(configPath) ? readFileSync(configPath, 'utf8') : '';

function requirePattern(pattern, message) {
  if (!pattern.test(source)) failures.push(message);
}
function warnPattern(pattern, message) {
  if (pattern.test(source)) warnings.push(message);
}

// Configuration must remain fail-closed until a reviewed release process exists.
if (!config) failures.push('Missing staging/config/config.js.');
if (/PRODUCTION_MODE\s*:\s*true/.test(config)) failures.push('Production mode is enabled in the committed browser config.');
if (/SUPABASE_URL\s*:\s*['"][^'"]+['"]/.test(config)) failures.push('Supabase URL is filled in the committed browser config; verify this is intentional.');
if (/SUPABASE_ANON_KEY\s*:\s*['"][^'"]{20,}['"]/.test(config)) failures.push('A long Supabase browser key is committed in config; keep secrets out of source and review public configuration deliberately.');
if (/service_role|sb_secret_/i.test(config)) failures.push('Possible service-role/secret key marker found in browser config.');

// Known legacy/demo paths are reported as stop-ship until explicitly removed or
// proven unreachable by an automated browser test and a source-level guard.
requirePattern(/function\s+makeMockSupabase\s*\(/, 'Mock Supabase client was not found; review whether the intended local-preview fallback still works.');
warnPattern(/function\s+makeMockSupabase\s*\(/, 'Mock backend exists in the source. Prove it cannot run on any hosted production path.');
requirePattern(/if\s*\(!localPreview\s*\|\|\s*config\.PRODUCTION_MODE\s*===\s*true\)/, 'Hosted boot must not use the preview identity.');
requirePattern(/const localPreview=location\.protocol==='file:'\|\|\['localhost','127\.0\.0\.1','::1'\]\.includes\(location\.hostname\); const DEV_BYPASS=localPreview;/, 'Legacy API bypass must be local-preview-only.');
requirePattern(/Server-backed modules are unavailable\. Sign-in requires the configured application API\./, 'Hosted legacy adapter failure must remain fail-closed.');
if (/\#prime-prod-gate\{display:none!important\}/.test(source)) failures.push('Production API gate is force-hidden by CSS.');
requirePattern(/if\s*\(_bokanProdConfigured\)\s*window\.sb\s*=\s*sb/, 'Configured Supabase client must be available to production bridge modules.');
requirePattern(/https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2\.118\.0/, 'Supabase browser SDK must be pinned to an exact reviewed version.');
requirePattern(/if\s*\(_bokanProdConfigured\)\s*\{\s*alert\('Document uploads are temporarily disabled/, 'Production document uploads must be blocked until private Storage is implemented.');
requirePattern(/Document downloads are temporarily disabled until private storage and authorized downloads are configured/, 'Production document listing/download links must remain blocked until private signed downloads are implemented.');
requirePattern(/Only an authenticated administrator can request role changes/, 'Role-change UI must reject non-admin production requests.');
requirePattern(/Only an authorized administrator or accounting user can request issuer TIN changes/, 'Production issuer TIN edits must be role-restricted.');
requirePattern(/Only an authorized administrator or accounting user can request issuer contact changes/, 'Production issuer contact edits must be role-restricted.');
requirePattern(/async function bokanProdSaveBanks\(key,banks\)\{ if\(_bokanProdConfigured\) throw new Error\('Bank account changes are temporarily disabled/, 'Production bank-account replacement must remain blocked until atomic audited writes exist.');
warnPattern(/bootResult\.catch\(function\(err\)\s*\{[\s\S]{0,250}?getElementById\(['"]app-view['"]\)\?\.classList\.remove\(['"]hidden['"]\)/, 'Boot error handler may reveal the application instead of failing closed.');
warnPattern(/async\s+signInWithPassword\s*\(\)\s*\{\s*return\s*\{\s*error\s*:\s*null\s*\}/, 'Mock sign-in appears to accept any credentials.');
warnPattern(/getPublicUrl\s*\(/, 'A public Storage URL helper is used. Confirm every file is intended to be public; sensitive files should use private storage and authorized downloads.');
warnPattern(/\.from\(['"](?:customers|customer_logs|employees|leave_requests|performance_reviews|expenses|sales_targets|stock_entries|stock_ledger|trip_plans|visit_reports|documents|proformas)['"]\)\.(?:insert|update|upsert|delete)\s*\(/, 'Legacy table mutation paths remain. Verify company isolation and least-privilege policies for every legacy path.');
warnPattern(/\.from\(['"]profiles['"]\)\.update\(\s*\{\s*role\s*\}/, 'Client code can attempt to update a profile role. RLS/grants must deny this except through a controlled admin path.');
warnPattern(/\.rpc\(['"]next_proforma_no['"]/, 'Legacy proforma-number RPC path remains alongside the newer numbering function.');
warnPattern(/\.rpc\(['"]bokan_next_proforma_number['"]/, 'New proforma-number RPC is referenced; confirm the function is company-scoped, concurrency-safe, and has restricted EXECUTE grants.');

// Basic coverage markers: these do not validate the implementation itself.
const requiredMarkers = [
  ['production guard', /_bokanProdConfigured/],
  ['profile verification', /company_code,active,terminated_at/],
  ['authenticated sign-in flow', /signInWithPassword\(\{email,password\}\)/],
  ['new proforma numbering', /bokan_next_proforma_number/],
];
for (const [label, pattern] of requiredMarkers) {
  if (!pattern.test(source)) failures.push(`Expected source marker missing: ${label}.`);
}

console.log('BOKAN ERP static source audit');
console.log(`Source bytes: ${Buffer.byteLength(source, 'utf8')}`);
console.log(`Static warnings: ${warnings.length}`);
for (const item of warnings) console.log(`WARN: ${item}`);
console.log(`Static failures: ${failures.length}`);
for (const item of failures) console.log(`FAIL: ${item}`);

if (warnings.length || failures.length) {
  console.log('\nRESULT: NOT CLEARED FOR PRODUCTION. Review all findings and run real Auth/RLS/Storage/browser tests.');
  process.exitCode = 1;
} else {
  console.log('\nRESULT: Static checks passed only. This is not production security approval.');
}
