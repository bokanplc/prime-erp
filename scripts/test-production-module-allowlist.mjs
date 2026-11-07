#!/usr/bin/env node
/** Exercise the source-reviewed production module gate without enabling production in config. */
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const start = source.indexOf("window.BOKAN_REVIEWED_PRODUCTION_TABS = Object.freeze(['policyhandbook']);");
const end = source.indexOf('const _bokanProdConfigured', start);
assert.ok(start >= 0 && end > start, 'Source-controlled production tab gate must exist before Supabase client initialization.');
const gateSource = source.slice(start, end);

function loadGate(code) {
  const sandbox = { window: {} };
  vm.runInNewContext(code, sandbox);
  return sandbox.window.BOKAN_HAS_REVIEWED_PRODUCTION_TAB;
}

const currentGate = loadGate(gateSource);
assert.equal(currentGate({ ENABLED_PRODUCTION_TABS: ['policyhandbook'] }), true,
  'The explicitly source-reviewed handbook should pass when explicitly enabled in config.');
assert.equal(currentGate({ ENABLED_PRODUCTION_TABS: ['proforma'] }), false,
  'A config-only Proforma enablement must be rejected.');
assert.equal(currentGate({ ENABLED_PRODUCTION_TABS: ['sales', 'payroll'] }), false,
  'Unreviewed operational and HR tabs must remain blocked.');
assert.equal(currentGate({ ENABLED_PRODUCTION_TABS: [] }), false,
  'An empty module list must keep production disabled.');
assert.equal(currentGate({}), false,
  'Missing module configuration must keep production disabled.');

const hypotheticalReviewedSource = gateSource.replace(
  "Object.freeze(['policyhandbook'])",
  "Object.freeze(['policyhandbook','sales'])"
);
assert.notEqual(hypotheticalReviewedSource, gateSource,
  'Test fixture must simulate an additional source-reviewed tab without changing production source.');
const expandedGate = loadGate(hypotheticalReviewedSource);
assert.equal(expandedGate({ ENABLED_PRODUCTION_TABS: ['sales'] }), true,
  'A newly source-reviewed tab should pass only when explicitly enabled in config.');
assert.equal(expandedGate({ ENABLED_PRODUCTION_TABS: ['payroll'] }), false,
  'A tab not in the source allowlist must remain blocked.');

console.log('PASS: production module gate requires agreement between source review and config; handbook is the sole reviewed module.');
