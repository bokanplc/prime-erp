import fs from 'node:fs';
import assert from 'node:assert/strict';
const source=fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html','utf8');
assert.equal(source,fs.readFileSync('staging/index.html','utf8'),'Source and entry must match.');
for(const [id,label] of [['bokan-v65-finance-production','Finance'],['bokan-v66-hr-production','HR']]){
 const start=source.indexOf('<script id="'+id+'">'),end=source.indexOf('</script>',start);
 assert.ok(start>=0&&end>start,id+' must remain present but benched.');
 const block=source.slice(start,end);
 assert.match(block,/const prod=false;/,label+' production adapter must be disabled.');
}
const financeStart=source.indexOf('<script id="bokan-v65-finance-production">'),financeEnd=source.indexOf('</script>',financeStart);
const finance=source.slice(financeStart,financeEnd);
assert.ok(finance.includes('Peachtree remains the accounting system'),'Finance adapter must document Peachtree as the accounting system.');
assert.ok(finance.includes('Accounting and journal posting are outside BOKAN ERP V7 scope'),'Journal posting must fail closed.');
const hrStart=source.indexOf('<script id="bokan-v66-hr-production">'),hrEnd=source.indexOf('</script>',hrStart);
const hr=source.slice(hrStart,hrEnd);
assert.ok(hr.includes('HR and Payroll are benched for V7'),'HR adapter must clearly report the deferral.');
console.log('PASS: V7 production adapters fail closed for HR/Payroll and accounting; Peachtree boundary is preserved.');
