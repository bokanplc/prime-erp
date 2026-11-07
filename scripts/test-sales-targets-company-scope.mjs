import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const index = fs.readFileSync('staging/index.html', 'utf8');
assert.equal(source, index, 'The full V6.7 source and staging entry must remain synchronized');

const submit = source.slice(source.indexOf("document.getElementById('target-form').addEventListener"), source.indexOf('function editTarget('));
assert.ok(submit.includes('company_id: productionCompanyId'), 'New targets must be written with the active company ID');
assert.ok(submit.includes("query.eq('company_id', productionCompanyId)"), 'Target updates must be scoped to the active company');
assert.ok(submit.includes('active company before saving a sales target'), 'Target creation must fail closed without company context');

const remove = source.slice(source.indexOf('async function deleteTarget('), source.indexOf('async function loadSalesTargets('));
assert.ok(remove.includes("query.eq('company_id', companyId)"), 'Target deletion must be scoped to the active company');
assert.ok(remove.includes('if (error)'), 'Target deletion errors must be surfaced');

const load = source.slice(source.indexOf('async function loadSalesTargets()'), source.indexOf('function renderSalesTargets'));
assert.ok(load.includes("tq.eq('company_id', productionCompanyId)"), 'Target reads must be explicitly scoped to the active company');
assert.ok(load.includes("['owner','admin','manager'].includes(role)"), 'Only manager-level roles should see target administration controls');
assert.ok(load.includes('targetError'), 'Target read errors must not be silently ignored');

console.log('PASS: Sales Targets are company-scoped, fail closed without company context, and hide manager controls from non-managers.');
