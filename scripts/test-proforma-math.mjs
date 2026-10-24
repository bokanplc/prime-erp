#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source=readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html','utf8');
const start=source.indexOf('function calculateBokanProformaTotals(');
const end=source.indexOf('\n}',start);
assert.ok(start>=0&&end>start,'Shared Proforma calculation helper must exist in the actual UI source.');
const helperSource=source.slice(start,end+2);
const calculate=vm.runInNewContext('('+helperSource+')');

const discounted=calculate([{qty:1,unit_price:11500}],15,10,true,3,10000);
assert.deepEqual({...discounted},{
  grossMerchandise:11500,discountAmount:1150,subtotalBeforeVAT:10000,
  vatAmount:1500,discountedGross:10350,grandTotal:10350,
  withholdingAmount:310.5,netPayable:10039.5
});

const noWithholdingAtThreshold=calculate([{qty:1,unit_price:10000}],15,0,true,3,10000);
assert.equal(noWithholdingAtThreshold.grandTotal,10000);
assert.equal(noWithholdingAtThreshold.withholdingAmount,0,'Threshold is strictly greater than ETB 10,000.');

const discountDropsBelowThreshold=calculate([{qty:1,unit_price:11000}],15,10,true,3,10000);
assert.equal(discountDropsBelowThreshold.grandTotal,9900);
assert.equal(discountDropsBelowThreshold.withholdingAmount,0,'Withholding is based on the final grand total after discount.');

const inclusivePrice=calculate([{qty:1,unit_price:6025}],15,0,true,3,10000);
assert.equal(inclusivePrice.subtotalBeforeVAT,5239.13);
assert.equal(inclusivePrice.vatAmount,785.87);
assert.equal(inclusivePrice.grandTotal,6025,'VAT must not be added on top of VAT-inclusive unit prices.');

const noVat=calculate([{qty:1,unit_price:6025}],0,0,false,3,10000);
assert.equal(noVat.subtotalBeforeVAT,6025);
assert.equal(noVat.vatAmount,0);
assert.equal(noVat.netPayable,6025);

for(const value of [discounted, noWithholdingAtThreshold, discountDropsBelowThreshold, inclusivePrice, noVat]){
  assert.ok(Math.abs(value.subtotalBeforeVAT+value.vatAmount-value.discountAmount-value.grandTotal)<=0.02,
    'Displayed subtotal + VAT - discount must equal grand total.');
}
console.log('PASS: actual Proforma UI math helper matches VAT-inclusive pricing, discount display, rounding and withholding threshold rules.');
