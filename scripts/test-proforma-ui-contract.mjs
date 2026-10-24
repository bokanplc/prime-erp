#!/usr/bin/env node
import fs from 'node:fs';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const sql = fs.readFileSync('docs/CORE_PROFORMA_MVP_SCHEMA_DRAFT.sql', 'utf8');

const bridgeStart = source.indexOf('async function bokanProdSaveProforma(payload,existing)');
const bridgeEnd = source.indexOf('function bokanProductionCacheRecord', bridgeStart);
assert.ok(bridgeStart >= 0 && bridgeEnd > bridgeStart, 'Production proforma save bridge must exist.');
const bridge = source.slice(bridgeStart, bridgeEnd);

for (const key of [
  'customer','tin','address','phone','contactPerson','date','vatPct','discountPct',
  'delivery','notes','withholdingEnabled','withholdingRate','withholdingThreshold','items'
]) {
  assert.ok(bridge.includes(key + ':payload.' + key), 'UI RPC payload mapping is missing ' + key);
}
assert.match(bridge, /p_company:\s*payload\.companyKey/, 'Company code must be passed to the RPC.');
assert.match(bridge, /p_existing_id:\s*existing\?\.id\|\|null/, 'Revision must pass the existing row ID.');
assert.match(bridge, /terms:\s*payload\.terms\|\|\[\]/, 'Commercial terms must be passed as an array.');

assert.match(source, /const items = \[\.\.\.document\.querySelectorAll\('#pf-items > div'\)\]\.map\(row => \(\{[\s\S]{0,500}description:[\s\S]{0,200}spec:[\s\S]{0,200}qty:[\s\S]{0,200}unit_price:/, 'The Proforma UI must preserve description, specification, quantity and VAT-inclusive unit_price fields.');
assert.match(source, /productionSavedRecord=await bokanProdSaveProforma\([\s\S]{0,350}items,terms\s*\},\s*existing\)/, 'The UI must pass the current item array and terms to the production RPC.');
assert.match(source, /function restoreProformaFormState\(x\)[\s\S]{0,900}\(x\.items\|\|\[\]\)\.forEach\(i=>addProformaItem\(i\)\)/, 'Saved item rows must be restored into the Proforma editor.');
assert.match(source, /row\.querySelector\('\.pf-desc'\)\.value=data\.description\|\|''/, 'Restored rows must read the saved item description.');
assert.match(source, /row\.querySelector\('\.pf-spec'\)\.value=data\.spec\|\|''/, 'Restored rows must read the saved item specification.');
assert.match(source, /row\.querySelector\('\.pf-price'\)\.value=data\.unit_price\|\|''/, 'Restored rows must read the saved VAT-inclusive unit price.');
assert.match(source, /row\.querySelector\('\.pf-qty'\)\.value=data\.qty\|\|''/, 'Restored rows must read the saved quantity.');

assert.match(sql, /v_items := p_payload->'items';/, 'The database function must retain the submitted item JSON.');
assert.match(sql, /item\.value->>'description'[\s\S]*?item\.value->>'qty'[\s\S]*?item\.value->>'unit_price'/, 'Database item validation must use the UI item field names.');
assert.match(sql, /sum\(\(item\.value->>'qty'\)::numeric \* \(item\.value->>'unit_price'\)::numeric\)/, 'Database totals must use VAT-inclusive unit_price values.');
assert.match(sql, /v_discounted_gross := round\(v_gross - v_discount_amount,2\)/, 'Database discount calculation must match the UI formula.');
assert.match(sql, /v_subtotal := round\(v_gross \/ \(1 \+ v_vat_rate \/ 100\),2\)/, 'VAT-exclusive subtotal must be calculated from the pre-discount VAT-inclusive gross.');
assert.match(sql, /v_vat_amount := round\(v_gross - v_subtotal,2\)/, 'VAT amount must be gross minus before-VAT subtotal.');
assert.match(sql, /abs\(grand_total - subtotal_before_vat - vat_amount \+ discount_amount\) <= 0\.02/, 'Displayed subtotal + VAT - discount must equal grand total.');
assert.match(source, /const subtotalBeforeVAT = Math\.round\(grossMerchandise \/ \(1 \+ vatPct\/100\) \* 100\)\/100/, 'UI subtotal must be computed before the separate discount row.');
assert.match(source, /const vatAmount = Math\.round\(\(grossMerchandise - subtotalBeforeVAT\)\*100\)\/100/, 'UI VAT must reconcile to the pre-discount inclusive gross.');
assert.match(source, /const grandTotal = discountedGross/, 'UI grand total must subtract the separately displayed discount.');
assert.match(sql, /when v_withholding_enabled and v_grand_total > v_withholding_threshold\s+then round\(v_grand_total \* v_withholding_rate \/ 100,2\)/, 'Withholding must apply only above the configured inclusive-total threshold.');
assert.match(sql, /v_net_payable := round\(v_grand_total - v_withholding_amount,2\)/, 'Net payable must equal grand total less withholding.');
assert.doesNotMatch(sql, /p_payload->>'(?:grandTotal|subtotalBeforeVAT|vatAmount|netPayable)'/, 'Client-supplied totals must not be trusted.');
assert.match(sql, /create or replace function public\.bokan_save_proforma[\s\S]*?security invoker[\s\S]*?select private\.bokan_save_proforma/, 'Public save endpoint must remain an invoker wrapper around the private transaction.');
assert.match(sql, /revoke all on public\.companies, public\.profiles, public\.company_bank_accounts, public\.custom_terms, public\.proformas from anon, authenticated;[\s\S]*?grant select on public\.proformas to authenticated;/, 'Authenticated users must not have direct proforma write grants.');
assert.match(source, /from\('custom_terms'\)\.select\('\*'\)\.eq\('company_code', companyKey\)/, 'Custom terms must be loaded only for the selected company.');
assert.match(source, /company_code: companyKey, category, label, created_by: currentUser\?\.id/, 'Custom terms must be saved with the selected company and authenticated creator.');

console.log('PASS: Proforma UI payload, saved-row restoration, financial math and trusted RPC contract match.');
