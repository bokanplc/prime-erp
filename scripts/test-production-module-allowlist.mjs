#!/usr/bin/env node
/** Exercise the real production module gate with the current and a test-only approved tab set. */
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const start = source.indexOf('window.BOKAN_REVIEWED_PRODUCTION_TABS = Object.freeze([]);');
const end = source.indexOf('const _bokanProdConfigured', start);
assert.ok(start >= 0 && end > start, 'Source-controlled production tab gate must exist before Supabase client initialization.');
const gateSource = source.slice(start, end);

function loadGate(code) {
  const sandbox = { window: {} };
  vm.runInNewContext(code, sandbox);
  return sandbox.window.BOKAN_HAS_REVIEWED_PRODUCTION_TAB;
}

const currentGate = loadGate(gateSource);
assert.equal(currentGate({ ENABLED_PRODUCTION_TABS: ['proforma'] }), false,
  'A config-only Proforma enablement must be rejected while source review allowlist is empty.');
assert.equal(currentGate({ ENABLED_PRODUCTION_TABS: ['sales', 'payroll'] }), false,
  'Config-only tabs must not become production-approved.');
assert.equal(currentGate({ ENABLED_PRODUCTION_TABS: [] }), false,
  'An empty module list must keep production disabled.');
assert.equal(currentGate({}), false,
  'Missing module configuration must keep production disabled.');

const hypotheticalReviewedSource = gateSource.replace(
  'Object.freeze([])',
  "Object.freeze(['proforma'])"
);
assert.notEqual(hypotheticalReviewedSource, gateSource,
  'Test fixture must simulate a source-reviewed module without changing production source.');
const reviewedGate = loadGate(hypotheticalReviewedSource);
assert.equal(reviewedGate({ ENABLED_PRODUCTION_TABS: ['proforma'] }), true,
  'A tab explicitly approved in source and enabled in config should pass the module gate.');
assert.equal(reviewedGate({ ENABLED_PRODUCTION_TABS: ['sales'] }), false,
  'A tab not in the source allowlist must remain blocked.');
assert.equal(reviewedGate({ ENABLED_PRODUCTION_TABS: [] }), false,
  'A reviewed tab must still be explicitly enabled in config.');

console.log('PASS: production module gate requires agreement between source review and config.');
