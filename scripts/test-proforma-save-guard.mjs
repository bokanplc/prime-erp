#!/usr/bin/env node
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const start = source.indexOf('let _bokanProformaSaveInFlight = false;');
const end = source.indexOf('function addProformaBankAccount(data={})', start);
assert.ok(start >= 0 && end > start, 'Guarded Proforma wrapper must exist before the bank-account helpers.');
const wrapper = source.slice(start, end);

function makeHarness(internal) {
  const attributes = new Map();
  const button = {
    disabled: false,
    textContent: 'Generate & Save Proforma',
    setAttribute(name, value) { attributes.set(name, value); },
    removeAttribute(name) { attributes.delete(name); },
    hasAttribute(name) { return attributes.has(name); }
  };
  const alerts = [];
  const logs = [];
  const context = {
    document: { querySelector(selector) {
      assert.equal(selector, 'button[onclick="generateProforma()"]');
      return button;
    } },
    generateProformaInternal: internal,
    alert: message => alerts.push(message),
    console: { error: (...args) => logs.push(args) }
  };
  vm.runInNewContext(wrapper + '\n globalThis.__runGuardedProforma = generateProforma; globalThis.__isSaving = () => _bokanProformaSaveInFlight;', context);
  return { context, button, attributes, alerts, logs };
}

let releaseSave;
let calls = 0;
const harness = makeHarness(() => {
  calls += 1;
  return new Promise(resolve => { releaseSave = resolve; });
});

const first = harness.context.__runGuardedProforma();
assert.equal(calls, 1, 'First click must start exactly one save.');
assert.equal(harness.context.__isSaving(), true, 'Save lock must be set synchronously before awaiting.');
assert.equal(harness.button.disabled, true, 'Save button must be disabled while save is pending.');
assert.equal(harness.button.textContent, 'Saving Proforma…', 'Button must communicate the pending state.');
assert.equal(harness.button.hasAttribute('aria-busy'), true, 'Button must expose the busy state accessibly.');

await harness.context.__runGuardedProforma();
assert.equal(calls, 1, 'A second click during an active save must not start another save.');

releaseSave({ id: 'test-record' });
await first;
assert.equal(harness.context.__isSaving(), false, 'Save lock must clear after success.');
assert.equal(harness.button.disabled, false, 'Save button must be re-enabled after success.');
assert.equal(harness.button.textContent, 'Generate & Save Proforma', 'Original button label must be restored.');
assert.equal(harness.button.hasAttribute('aria-busy'), false, 'Busy state must be removed after success.');

const failure = makeHarness(() => Promise.reject(new Error('simulated failure')));
await failure.context.__runGuardedProforma();
assert.equal(failure.context.__isSaving(), false, 'Save lock must clear after an unexpected error.');
assert.equal(failure.button.disabled, false, 'Save button must be re-enabled after an unexpected error.');
assert.equal(failure.button.textContent, 'Generate & Save Proforma', 'Original button label must be restored after an unexpected error.');
assert.equal(failure.button.hasAttribute('aria-busy'), false, 'Busy state must be removed after an unexpected error.');
assert.equal(failure.alerts.length, 1, 'Unexpected error should show one user-facing alert.');

console.log('PASS: Proforma save guard blocks concurrent clicks and always restores the UI after success or failure.');
