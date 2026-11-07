#!/usr/bin/env node
import fs from 'node:fs';
import assert from 'node:assert/strict';

const source=fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html','utf8');
const entry=fs.readFileSync('staging/index.html','utf8');
assert.equal(source,entry,'The full V6.7 source and staging entry must remain byte-for-byte synchronized.');
const access=source.match(/<script id="bokan-v74-production-access-registry">([\\s\\S]*?)<\\/script>/);
assert.ok(access,'Production access registry bridge must exist.');
const bridge=access[1];
for(const needle of [
  "from('company_memberships')",
  "from('profiles')",
  ".eq('company_id',companyId)",
  "functions.invoke('invite-blackrock-member'",
  "['sales','staff']",
  "Only a BlackRock owner or administrator can invite employees.",
  "Direct activation and deactivation are temporarily disabled",
  "Customer assignment reporting will be available after the new reconciled customer data",
  "if(!ctx()?.enabled){if(reviewAdd)reviewAdd();return;}"
])assert.ok(bridge.includes(needle),`Missing production access safeguard: ${needle}`);
assert.ok(!bridge.includes("localStorage.setItem"),'Production membership changes must not write browser-local access records.');
assert.ok(!bridge.includes("from('customers')"),'Production access view must not inspect old customer records before fresh data onboarding.');
console.log('PASS: Production access registry reads same-company memberships, invites only Sales/Data Entry via the secured Edge Function, and blocks unsafe local/demo mutations.');
