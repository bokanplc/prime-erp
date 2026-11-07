import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const match = source.match(/<script id="bokan-v72-sales-orders-production-bridge">([\s\S]*?)<\/script>/);
assert.ok(match, 'V6.7 production Sales Orders bridge must exist');

new vm.Script(match[1], { filename: 'bokan-v72-sales-orders-production-bridge.js' });

const bridge = match[1];
for (const [needle, message] of [
  ['window.BOKAN_PRODUCTION_AUTH', 'The bridge must use the production authentication context.'],
  ['auth()?.enabled===true', 'The bridge must only intercept writes in production mode.'],
  ["rpc('create_sales_document_with_items'", 'The bridge must create drafts through the guarded RPC.'],
  ['stopImmediatePropagation()', 'The bridge must prevent the legacy localStorage submit handler in production.'],
  ['salesperson_id:salespersonId', 'The bridge must attribute every draft to a sales representative.'],
  ["toSelect('so-customer','Select customer')", 'The bridge must use a canonical customer selection.'],
  ["toSelect('so-product','Select product')", 'The bridge must use a canonical product selection.'],
  ["toSelect('so-rep','Select sales representative')", 'The bridge must use an active sales representative selection.'],
  ['No stock movement or payment was recorded.', 'Draft creation must not post stock or payments.'],
  ['Unit selling price (ETB)', 'The form must capture unit selling price, not divide an order total into rounded unit costs.']
]) assert.ok(source.includes(needle) || bridge.includes(needle), message);

assert.ok(bridge.includes("document_type:'sales_order'"), 'New sales orders must be created as drafts of type sales_order.');
assert.ok(bridge.includes("status('Sales order saved as a draft."), 'The UI must clearly report draft-only save semantics.');
assert.ok(bridge.includes("if(!productionConfigured())return;"), 'Preview/localStorage mode must remain separate from production mode.');

console.log('PASS: Sales Orders UI uses the guarded production draft RPC, salesperson attribution, and no localStorage fallback in production.');
