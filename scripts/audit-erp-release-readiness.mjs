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

const direct = [...new Set([...source.matchAll(/\\.from\\(\\s*['"]([a-z][a-z0-9_]*)['"]\\s*\\)/g)].map(m=>m[1]))];
const helper = [...new Set([...source.matchAll(/\\b(?:insert|update|q|count)\\s*\\(\\s*['"]([a-z][a-z0-9_]*)['"]/g)].map(m=>m[1]).filter(t=>t.startsWith('bokan_')))];
const referenced = [...new Set([...direct,...helper])].sort();
const defined = [...new Set([...schema.matchAll(/create\\s+table\\s+(?:if\\s+not\\s+exists\\s+)?public\\.([a-z][a-z0-9_]*)/gi)].map(m=>m[1]))].sort();
const missing = referenced.filter(table=>!defined.includes(table));

const apiRequired = [
  '/api/auth/login',
  '/api/auth/change-password',
  '/api/auth/logout',
  '/api/bootstrap',
  '/api/store/'
];
const functionFiles = [
  'functions/api/auth/login.js',
  'functions/api/auth/change-password.js',
  'functions/api/auth/logout.js',
  'functions/api/bootstrap.js',
  'functions/api/store/[[path]].js',
  'functions/api/store/[key].js'
];
const presentFunctionFiles = functionFiles.filter(path=>existsSync(path));
const apiBackendPresent = presentFunctionFiles.length >= 5;
const productionMode = /PRODUCTION_MODE\\s*:\\s*true/.test(config);
const fullDataReady = /FULL_ERP_DATA_READY\\s*:\\s*true/.test(config);
const blockers = [];
if(missing.length) blockers.push('Missing database table definitions ('+missing.length+'/'+referenced.length+'): '+missing.join(', '));
if(!apiBackendPresent) blockers.push('Legacy authenticated /api backend is not implemented in the expected Cloudflare Pages Functions locations.');
if(!/SUPABASE_URL\\s*:\\s*""/.test(config) || !/SUPABASE_ANON_KEY\\s*:\\s*""/.test(config)) {
  // A configured browser key is not a release approval; the full readiness gate must still be satisfied.
  console.log('INFO: browser Supabase configuration is non-empty; this is not proof of schema or RLS readiness.');
}
if(!/create or replace function public\\.bokan_save_proforma/.test(schema)) blockers.push('Trusted proforma save function is missing from the reviewed first-slice schema.');
if(!/enable row level security/i.test(schema)) blockers.push('The schema draft contains no RLS enablement.');

console.log('BOKAN ERP full-release readiness audit');
console.log('Referenced logical database tables: '+referenced.length);
console.log('Tables defined in current first-slice schema: '+defined.length+' ('+defined.join(', ')+')');
console.log('Tables still missing schema: '+missing.length);
console.log('Legacy API backend files found: '+presentFunctionFiles.length+'/'+functionFiles.length);
console.log('PRODUCTION_MODE: '+productionMode);
console.log('FULL_ERP_DATA_READY: '+fullDataReady);
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
