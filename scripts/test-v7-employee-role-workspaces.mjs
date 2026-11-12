import fs from 'node:fs';
import assert from 'node:assert/strict';
const source=fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html','utf8');
assert.equal(source,fs.readFileSync('staging/index.html','utf8'),'Source and entry must match.');
const start=source.indexOf('const ROLE_TABS = {');
const end=source.indexOf('\n};',start);
assert.ok(start>=0&&end>start,'Role tab matrix must exist.');
const matrix=source.slice(start,end);
const dataEntry=matrix.match(/data_entry:\s*\[([^\]]+)\]/)?.[1]||'';
for(const tab of ['sales','salescalllog','salespipeline','salesorders','proformarequest','masterdata','procurement','supplytower','dataentry','repository','policyhandbook'])assert.ok(dataEntry.includes("'"+tab+"'"),'Data-entry users need the '+tab+' operational workspace.');
for(const tab of ['collections','generalledger','receivables','payables','bankcash','payroll'])assert.ok(!dataEntry.includes("'"+tab+"'"),'Data-entry role must not access '+tab+'.');
const sales=matrix.match(/sales:\s*\[([^\]]+)\]/)?.[1]||'';
for(const tab of ['salespipeline','salesorders','salestargets','proformarequest'])assert.ok(sales.includes("'"+tab+"'"),'Sales reps need '+tab+'.');
const manager=matrix.match(/sales_manager:\s*\[([^\]]+)\]/)?.[1]||'';
assert.ok(!manager.includes("'collections'"),'Sales managers must not see the parked collections module.');

const admin=matrix.match(/admin:\s*\[([^\]]+)\]]+)\\]/)?.[1]||'';
for(const tab of ['sales','salespipeline','salesorders','procurement','inventorycontrol','supplytower','masterdata','accesscontrol'])assert.ok(admin.includes("'"+tab+"'"),'V7 owners need '+tab+'.');
for(const tab of ['collections','billing','generalledger','receivables','payables','bankcash','fixedassets','budgetcontrol','payroll','hremployees','hrleave','hrperformance','hrdisciplinary'])assert.ok(!admin.includes("'"+tab+"'"),'V7 owners must not see parked '+tab+'.');
const management=matrix.match(/management:\s*\[([^\]]+)\]]+)\\]/)?.[1]||'';
for(const tab of ['salespipeline','salesorders','salestargets','supplytower'])assert.ok(management.includes("'"+tab+"'"),'Management needs '+tab+'.');
for(const tab of ['collections','generalledger','receivables','payables','bankcash','payroll','hrreports'])assert.ok(!management.includes("'"+tab+"'"),'Management must not see parked '+tab+'.');

console.log('PASS: V7 owner, manager, sales and data-entry roles are limited to the operational scope; HR/accounting/payment modules are excluded.');
