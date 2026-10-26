#!/usr/bin/env node
import fs from 'node:fs';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html','utf8');
const start = source.indexOf('id="bokan-v61-production-auth"');
const end = source.indexOf('id="bokan-v63-crm-production-bridge"', start);
assert.ok(start >= 0 && end > start, 'Production authentication bridge must be present and bounded.');
const auth = source.slice(start, end);
assert.match(auth, /from\('company_memberships'\)/, 'Authentication must derive access from the live company_memberships table.');
assert.match(auth, /companies\(id,code,name,is_active\)/, 'Membership lookup must join the live company master.');
assert.match(auth, /\.eq\('user_id',user\.id\)\.eq\('is_active',true\)/, 'Only the signed-in user active memberships may be considered.');
assert.match(auth, /m\.companies\?\.is_active/, 'Inactive companies must not authorize application access.');
assert.match(auth, /memberships\.find\(m=>m\.company_code===preferred\)\|\|memberships\[0\]/, 'Saved company context may select only a returned authorized membership.');
assert.match(auth, /owner:'admin',admin:'admin',manager:'management',sales:'sales',accountant:'accounting',staff:'data_entry'/, 'Only explicitly mapped live membership roles may enter supported ERP roles.');
assert.doesNotMatch(auth, /from\('profiles'\)/, 'The production login bridge must not depend on a profiles table absent from live Supabase.');
assert.match(auth, /sel\.disabled=companyCodes\.length<=1/, 'Company switching must be limited to actual active memberships.');
assert.match(source, /Production role changes are disabled until audited Supabase Auth user provisioning and company-membership management are implemented/, 'Production role changes must stay blocked until trusted provisioning exists.');
console.log('PASS: production authentication derives role/company from active live memberships and keeps unsupported roles and role changes blocked.');
