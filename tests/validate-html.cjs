const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('index.html', 'utf8');
const failures = [];
if (!html.includes('<title>BOKAN ERP')) failures.push('BOKAN ERP title is missing');
for (const id of ['authForm','resetForm','companySelect','customerForm','productForm','salesForm','lineItems','saveSales','supplierForm','purchaseForm','buyLineItems','addBuyLine','stockBalances','stockForm','paymentForm','supplierPaymentForm','supplierPaymentList','salesActionDoc','approveSalesBtn','postSalesBtn','li-product','supplier_payment_reconciliation']) {
  if (!html.includes('id="' + id + '"') && !html.includes("id='" + id + "'")) {
    failures.push('Required UI element is missing: ' + id);
  }
}
for (const id of ['tab-suppliers','tab-purchases','tab-inventory','tab-payments']) {
  if (!html.includes('id=\"' + id + '\"')) failures.push('New module panel is missing: ' + id);
}
if (!html.includes('sb_publishable_')) failures.push('Supabase publishable key is missing');
if (!html.includes("create_sales_document_with_items") || !html.includes("db.rpc(")) {
  failures.push('Atomic sales-document RPC integration is missing');
}
if (!html.includes("create_purchase_document_with_items") || !html.includes("buyLineData()")) {
  failures.push('Atomic purchase-document line-item integration is missing');
}
if (!html.includes("inventory_stock_balances")) {
  failures.push('Inventory stock-balance view integration is missing');
}
if (/db\.from\('sales_documents'\)\.insert\(/.test(html) || /db\.from\('sales_document_items'\)\.insert\(/.test(html)) {
  failures.push('Legacy two-step sales-document inserts remain in the UI');
}
if (/service_role|sb_secret_/i.test(html)) failures.push('A server-side Supabase secret-like key appears in the public HTML');
const scripts = [...html.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/gi)];
let checked = 0;
for (const match of scripts) {
  if (/\bsrc\s*=/.test(match[1])) continue;
  const source = match[2].trim();
  if (!source) continue;
  try { new vm.Script(source, { filename: 'index.html:inline-script-' + (++checked) }); }
  catch (err) { failures.push('Inline JavaScript syntax error: ' + err.message); }
}
if (checked === 0) failures.push('No inline application JavaScript was found');
if (failures.length) {
  console.error(failures.map(x => 'FAIL: ' + x).join('\n'));
  process.exit(1);
}
if (!html.includes('post_sales_document_stock')) failures.push('Sales stock posting RPC integration is missing');
if (!html.includes('record_supplier_payment') || !html.includes('reconcile_supplier_payment')) failures.push('Supplier payment and reconciliation RPC integration is missing');
if (!html.includes('supplier_payment_reconciliation')) failures.push('Supplier payment reconciliation view integration is missing');
if (failures.length) { console.error(failures.map(x => 'FAIL: ' + x).join('\\n')); process.exit(1); }
console.log('PASS: ' + checked + ' inline script(s) parse; sales, purchasing, inventory posting, supplier payment reconciliation and public-key safety checks passed.');
