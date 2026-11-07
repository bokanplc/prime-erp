import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const index = fs.readFileSync('staging/index.html', 'utf8');
const marker = '<script id="bokan-v73-sales-pipeline-production-bridge">';
const start = source.indexOf(marker);
const end = source.indexOf('</script>', start);
assert.ok(start >= 0 && end > start, 'V6.7 production Sales Pipeline bridge must exist');
const bridge = source.slice(start + marker.length, end);
new vm.Script(bridge, { filename: 'bokan-v73-sales-pipeline-production-bridge.js' });
for (const [needle, message] of [
  ['window.BOKAN_PRODUCTION_AUTH', 'The bridge must use the production authentication context.'],
  ['window.BOKAN_CRM_PRODUCTION?.enabled?.()', 'The bridge must require the canonical CRM production adapter.'],
  ['window.BOKAN_CRM_PRODUCTION.listMyCustomers()', 'The bridge must load canonical company customers.'],
  ['window.BOKAN_CRM_PRODUCTION.listOpportunities()', 'The bridge must load persisted CRM opportunities.'],
  ['window.BOKAN_CRM_PRODUCTION.createOpportunity(', 'The bridge must create opportunities through the canonical CRM adapter.'],
  ['stopImmediatePropagation()', 'The bridge must prevent the legacy localStorage submit handler in production.'],
  ["toSelect('sp-customer','Select customer')", 'The bridge must use canonical customer IDs, not free-text names.'],
  ["product_description:product", 'The opportunity must preserve the product/customer requirement.'],
  ['next_action_date:', 'The bridge must persist a dated next action.'],
  ['bokanPipelineProduction', 'Production initialization must be idempotent.']
]) assert.ok(bridge.includes(needle), message);

assert.ok(!bridge.includes('localStorage'), 'The production bridge must not use localStorage.');
assert.ok(index.includes('bokan-v73-sales-pipeline-production-bridge'), 'The full-app staging entry must include the Sales Pipeline bridge.');
assert.ok(source.includes('<input id="sp-product" required'), 'The V6.7 opportunity form must capture product or customer requirement.');
assert.equal(source, index, 'The full V6.7 source and staging entry must remain synchronized.');

console.log('PASS: Sales Pipeline UI persists opportunities through the canonical company-scoped CRM adapter with no production localStorage fallback.');
