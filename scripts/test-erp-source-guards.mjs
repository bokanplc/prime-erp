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
assert.match(config, /SUPABASE_URL\s*:\s*""/, 'Supabase URL placeholder must remain blank in the committed template.');
assert.match(config, /SUPABASE_ANON_KEY\s*:\s*""/, 'Supabase browser key placeholder must remain blank in the committed template.');

const bootStart = source.indexOf('async function boot()');
const bootEnd = source.indexOf('function showLanding', bootStart);
assert.ok(bootStart >= 0 && bootEnd > bootStart, 'Main boot function must exist.');
const boot = source.slice(bootStart, bootEnd);
const guardIndex = boot.indexOf('if (!localPreview || config.PRODUCTION_MODE === true)');
const previewIdentityIndex = boot.indexOf("currentUser = { id: 'preview-admin'");
assert.ok(guardIndex >= 0, 'Hosted origins and production-configured preview must be blocked from preview boot.');
assert.ok(previewIdentityIndex > guardIndex, 'Preview identity must only be assigned after the local-preview guard.');

const autoStart = source.indexOf('// Start local preview only on file/localhost');
const autoEnd = source.indexOf('</script>', autoStart);
assert.ok(autoStart >= 0 && autoEnd > autoStart, 'Boot error handler must exist.');
const autoBoot = source.slice(autoStart, autoEnd);
assert.match(autoBoot, /app-view['"]\)\?\.classList\.add\(['"]hidden['"]\)/, 'Startup failure must hide the app.');
assert.doesNotMatch(autoBoot, /app-view['"]\)\?\.classList\.remove\(['"]hidden['"]\)/, 'Startup failure must never reveal the app.');

assert.match(source, /if \(_bokanProdConfigured\) window\.sb = sb;/, 'Configured real Supabase client must be exposed to production bridge modules.');
assert.match(source, /id="bokan-v61-production-auth"/, 'Production authentication bridge must exist.');
assert.match(source, /id="bokan-v67-hosted-fail-closed"/, 'Hosted fail-closed guard must exist.');

console.log('PASS: BOKAN ERP source startup guards and staging entry-point parity.');
