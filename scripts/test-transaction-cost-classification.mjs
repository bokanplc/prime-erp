import fs from 'node:fs';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const index = fs.readFileSync('staging/index.html', 'utf8');
assert.equal(source, index, 'The complete application source and staging entry must remain identical.');

const start = source.indexOf('<script id="bokan-v69-transaction-costs">');
const end = source.indexOf('</script>', start);
assert.ok(start >= 0 && end > start, 'Transaction-cost module must exist.');
const moduleSource = source.slice(start, end);
assert.ok(moduleSource.includes("relatedType==='purchase_document'?'landed_cost':'direct_sales_cost'"), 'Purchase-linked costs must classify as landed costs; other transaction-linked costs must classify as direct sales costs.');
assert.ok(moduleSource.includes("/General Operating/.test(category)?'operating_expense'"), 'General operating expenses must remain separate from profitability costs.');
assert.ok(moduleSource.includes("$('tc-related-type')?.addEventListener('change',syncTransactionCostClass)"), 'Changing the linked document must reclassify the cost.');
assert.ok(moduleSource.includes("$('tc-category')?.addEventListener('change',syncTransactionCostClass)"), 'Changing the category must reclassify the cost.');
assert.ok(moduleSource.includes("related_document_type:$('tc-related-type').value||null"), 'The selected reference type must be persisted with the cost.');
assert.ok(moduleSource.includes("cost_class:$('tc-class').value"), 'The selected classification must be persisted.');
assert.ok(!moduleSource.includes("/Factory|Quality|Loading|Transport|Handling/"), 'Cost class must not be guessed from category wording alone.');

console.log('PASS: transaction costs are classified by their linked business document, with overhead kept separate.');
