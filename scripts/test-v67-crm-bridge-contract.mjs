#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const htmlPath=path.join(process.cwd(),'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html');
const entryPath=path.join(process.cwd(),'staging/index.html');
const source=fs.readFileSync(htmlPath,'utf8');
const entry=fs.readFileSync(entryPath,'utf8');
assert.equal(entry,source,'The staging entry must be byte-for-byte synchronized with the full V6.7 source.');

const start=source.indexOf('<script id="bokan-v63-crm-production-bridge">');
assert.ok(start>=0,'Canonical CRM production bridge must exist.');
const end=source.indexOf('</script>',start);
assert.ok(end>start,'CRM bridge script must be closed.');
const bridge=source.slice(start,end);

for(const table of ['customers','crm_customer_assignments','crm_assignment_events','crm_activities','crm_opportunities','crm_after_sales_tasks']){
  assert.ok(bridge.includes("'"+table+"'"),`CRM bridge must use canonical table ${table}.`);
}
for(const legacy of ['bokan_customers','bokan_customer_activities','bokan_customer_assignments','bokan_salespeople','bokan_sales_opportunities']){
  assert.ok(!bridge.includes(legacy),`CRM bridge must not reference legacy table ${legacy}.`);
}
for(const method of ['listMyCustomers','createCustomer','updateCustomer','listActivities','addActivity','assignCustomer','listOpportunities','createOpportunity','updateOpportunity','listAfterSalesTasks','createAfterSalesTask','updateAfterSalesTask','listCompanyRepresentatives']){
  assert.ok(bridge.includes(method),`CRM bridge method ${method} is missing.`);
}
assert.ok(bridge.includes("rpc('bokan_reassign_customer_owner'"),'Customer reassignment must use the manager-only RPC.');
assert.ok(bridge.includes("eq('company_id',company())"),'CRM writes and updates must be scoped to the selected company.');
assert.ok(bridge.includes('owner_user_id:user.id'),'New opportunities must be owned by the signed-in user.');
assert.ok(!bridge.includes('.delete('),'CRM bridge must not hard-delete customer or history records.');
console.log('PASS: V6.7 CRM bridge uses canonical company-scoped tables, guarded reassignment, append-only activity history, and synchronized full-app staging entry.');
