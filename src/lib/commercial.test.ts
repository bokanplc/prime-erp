import test from "node:test";
import assert from "node:assert/strict";
import { calculateCommercialResult } from "./commercial";

test("adds 15% VAT to an exclusive selling price", () => {
  const result = calculateCommercialResult({
    salesAmount: 10_000,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 7_000, vatTreatment: "none" }
  });
  assert.equal(result.revenueExcludingVat, 10_000);
  assert.equal(result.outputVat, 1_500);
  assert.equal(result.customerInvoiceTotal, 11_500);
  assert.equal(result.landedGrossProfit, 3_000);
});

test("extracts VAT from a VAT-inclusive selling price", () => {
  const result = calculateCommercialResult({
    salesAmount: 11_500,
    salesVatTreatment: "inclusive",
    landedPurchaseCost: { amount: 7_000, vatTreatment: "none" }
  });
  assert.equal(result.revenueExcludingVat, 10_000);
  assert.equal(result.outputVat, 1_500);
  assert.equal(result.customerInvoiceTotal, 11_500);
});

test("deducts recoverable VAT from a purchase cost, not from a non-recoverable cost", () => {
  const recoverable = calculateCommercialResult({
    salesAmount: 10_000,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 8_050, vatTreatment: "inclusive", recoverableVat: true }
  });
  const nonRecoverable = calculateCommercialResult({
    salesAmount: 10_000,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 8_050, vatTreatment: "inclusive", recoverableVat: false }
  });
  assert.equal(recoverable.landedPurchaseCost, 7_000);
  assert.equal(recoverable.recoverablePurchaseVat, 1_050);
  assert.equal(nonRecoverable.landedPurchaseCost, 8_050);
  assert.equal(nonRecoverable.recoverablePurchaseVat, 0);
});

test("subtracts transport, loading and miscellaneous direct costs", () => {
  const result = calculateCommercialResult({
    salesAmount: 20_000,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 12_000, vatTreatment: "none" },
    directCosts: [
      { amount: 500, vatTreatment: "none" },
      { amount: 250, vatTreatment: "none" },
      { amount: 150, vatTreatment: "none" }
    ]
  });
  assert.equal(result.landedGrossProfit, 8_000);
  assert.equal(result.directCosts, 900);
  assert.equal(result.profitAfterDirectCosts, 7_100);
});

test("rejects negative monetary values", () => {
  assert.throws(() => calculateCommercialResult({
    salesAmount: -1,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 1, vatTreatment: "none" }
  }), RangeError);
});

test("reports direct costs by transportation, loading and miscellaneous category", () => {
  const result = calculateCommercialResult({
    salesAmount: 10_000,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 6_000, vatTreatment: "none" },
    directCosts: [
      { amount: 300, vatTreatment: "none", category: "transportation" },
      { amount: 100, vatTreatment: "none", category: "loading" },
      { amount: 50, vatTreatment: "none", category: "miscellaneous" }
    ]
  });
  assert.equal(result.transportationCosts, 300);
  assert.equal(result.loadingCosts, 100);
  assert.equal(result.miscellaneousCosts, 50);
  assert.equal(result.directCosts, 450);
});

test("includes recoverable VAT on eligible direct costs separately", () => {
  const result = calculateCommercialResult({
    salesAmount: 10_000,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 6_000, vatTreatment: "none" },
    directCosts: [
      { amount: 1_150, vatTreatment: "inclusive", recoverableVat: true, category: "transportation" }
    ]
  });
  assert.equal(result.directCosts, 1_000);
  assert.equal(result.recoverableDirectCostVat, 150);
});

test("does not add VAT to a non-taxable sales amount", () => {
  const result = calculateCommercialResult({
    salesAmount: 10_000,
    salesVatTreatment: "none",
    landedPurchaseCost: { amount: 6_000, vatTreatment: "none" }
  });
  assert.equal(result.revenueExcludingVat, 10_000);
  assert.equal(result.outputVat, 0);
  assert.equal(result.customerInvoiceTotal, 10_000);
  assert.equal(result.landedGrossProfit, 4_000);
});

test("uses the active company VAT basis points rather than a global rate", () => {
  const result = calculateCommercialResult({
    salesAmount: 10_000,
    salesVatTreatment: "exclusive",
    landedPurchaseCost: { amount: 5_000, vatTreatment: "none" },
    vatBasisPoints: 500
  });
  assert.equal(result.outputVat, 500);
  assert.equal(result.customerInvoiceTotal, 10_500);
});

test("normalizes recoverable VAT using the active company rate", () => {
  const result = normalizeCommercialCost({
    amount: 10_500,
    vatTreatment: "inclusive",
    recoverableVat: true
  }, 500);
  assert.equal(result.expense, 10_000);
  assert.equal(result.recoverableVat, 500);
});
