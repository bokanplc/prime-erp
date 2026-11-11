export const STANDARD_VAT_BASIS_POINTS = 1_500;

export type VatTreatment = "exclusive" | "inclusive" | "none";

export type CostInput = {
  amount: number;
  vatTreatment: VatTreatment;
  recoverableVat?: boolean;
};

export type CommercialResultInput = {
  salesAmount: number;
  salesVatTreatment: Exclude<VatTreatment, "none">;
  landedPurchaseCost: CostInput;
  directCosts?: CostInput[];
  vatBasisPoints?: number;
};

export type NormalizedAmount = {
  net: number;
  vat: number;
  gross: number;
  expense: number;
};

export type CommercialResult = {
  currency: "ETB";
  vatBasisPoints: number;
  revenueExcludingVat: number;
  outputVat: number;
  customerInvoiceTotal: number;
  landedPurchaseCost: number;
  recoverablePurchaseVat: number;
  landedGrossProfit: number;
  directCosts: number;
  recoverableDirectCostVat: number;
  profitAfterDirectCosts: number;
  landedGrossMarginPercent: number | null;
  marginAfterDirectCostsPercent: number | null;
};

function toMinorUnits(amount: number): number {
  if (!Number.isFinite(amount) || amount < 0) {
    throw new RangeError("Amounts must be finite, non-negative ETB values.");
  }
  return Math.round((amount + Number.EPSILON) * 100);
}

function fromMinorUnits(amount: number): number {
  return amount / 100;
}

function normalize(
  amount: number,
  treatment: VatTreatment,
  vatBasisPoints: number,
  recoverableVat = false
): { net: number; vat: number; gross: number; expense: number } {
  const entered = toMinorUnits(amount);
  const divisor = 10_000 + vatBasisPoints;
  let net: number;
  let vat: number;
  let gross: number;

  if (treatment === "none") {
    net = entered;
    vat = 0;
    gross = entered;
  } else if (treatment === "inclusive") {
    net = Math.round((entered * 10_000) / divisor);
    vat = entered - net;
    gross = entered;
  } else {
    net = entered;
    vat = Math.round((net * vatBasisPoints) / 10_000);
    gross = net + vat;
  }

  return {
    net: fromMinorUnits(net),
    vat: fromMinorUnits(vat),
    gross: fromMinorUnits(gross),
    expense: fromMinorUnits(recoverableVat ? net : gross)
  };
}

/**
 * Pure commercial calculation only. This does not post accounting entries,
 * record receipts/payments, value inventory, or create a stock balance.
 * Amounts are ETB; VAT is calculated in integer cents to avoid float drift.
 */
export function calculateCommercialResult(
  input: CommercialResultInput
): CommercialResult {
  const vatBasisPoints = input.vatBasisPoints ?? STANDARD_VAT_BASIS_POINTS;
  if (!Number.isInteger(vatBasisPoints) || vatBasisPoints < 0 || vatBasisPoints > 100_000) {
    throw new RangeError("VAT basis points must be a whole number from 0 to 100000.");
  }

  const revenue = normalize(input.salesAmount, input.salesVatTreatment, vatBasisPoints);
  const landedCost = normalize(
    input.landedPurchaseCost.amount,
    input.landedPurchaseCost.vatTreatment,
    vatBasisPoints,
    input.landedPurchaseCost.recoverableVat ?? false
  );

  const directCosts = (input.directCosts ?? []).map((cost) =>
    normalize(cost.amount, cost.vatTreatment, vatBasisPoints, cost.recoverableVat ?? false)
  );

  const directCostMinor = directCosts.reduce((sum, cost) => sum + toMinorUnits(cost.expense), 0);
  const recoverableDirectVatMinor = directCosts.reduce(
    (sum, cost) => sum + toMinorUnits(cost.vat * ((cost.expense === cost.net) ? 1 : 0)),
    0
  );

  const revenueMinor = toMinorUnits(revenue.net);
  const landedCostMinor = toMinorUnits(landedCost.expense);
  const grossProfitMinor = revenueMinor - landedCostMinor;
  const afterDirectCostsMinor = grossProfitMinor - directCostMinor;

  return {
    currency: "ETB",
    vatBasisPoints,
    revenueExcludingVat: revenue.net,
    outputVat: revenue.vat,
    customerInvoiceTotal: revenue.gross,
    landedPurchaseCost: landedCost.expense,
    recoverablePurchaseVat: input.landedPurchaseCost.recoverableVat ? landedCost.vat : 0,
    landedGrossProfit: fromMinorUnits(grossProfitMinor),
    directCosts: fromMinorUnits(directCostMinor),
    recoverableDirectCostVat: fromMinorUnits(recoverableDirectVatMinor),
    profitAfterDirectCosts: fromMinorUnits(afterDirectCostsMinor),
    landedGrossMarginPercent:
      revenueMinor === 0 ? null : Number(((grossProfitMinor / revenueMinor) * 100).toFixed(2)),
    marginAfterDirectCostsPercent:
      revenueMinor === 0 ? null : Number(((afterDirectCostsMinor / revenueMinor) * 100).toFixed(2))
  };
}
