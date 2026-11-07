import fs from 'node:fs';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const index = fs.readFileSync('staging/index.html', 'utf8');
assert.equal(source, index, 'The full V6.7 source and staging entry must remain synchronized');

const submit = source.slice(source.indexOf("document.getElementById('expense-form').addEventListener"), source.indexOf('function editExpense('));
assert.ok(submit.includes('company_id: productionCompanyId'), 'Expense inserts and updates must include the active company ID');
assert.ok(submit.includes("query.eq('company_id', productionCompanyId)"), 'Expense updates must be company-scoped');
assert.ok(submit.includes('active company before saving an expense'), 'Expense writes must fail closed without company context');

const load = source.slice(source.indexOf('async function loadExpenses()'), source.indexOf('async function deleteExpense('));
assert.equal((load.match(/query.eq\('company_id', companyId\)/g)||[]).length, 2, 'Both expense lists must explicitly filter by company');
assert.ok(load.includes('Expenses could not be loaded'), 'Expense ledger read errors must be surfaced');
assert.ok(load.includes('Your expenses could not be loaded'), 'Personal expense read errors must be surfaced');

const remove = source.slice(source.indexOf('async function deleteExpense('), source.indexOf('function downloadExpenseCSV('));
assert.ok(remove.includes("query.eq('company_id', companyId)"), 'Expense deletion must be company-scoped');
assert.ok(remove.includes('Expense was not deleted'), 'Expense deletion errors must be surfaced');

console.log('PASS: Expense entry, update, ledger reads and deletion are explicitly scoped to the active company.');
