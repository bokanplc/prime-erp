"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";

const salesWriters = ["owner", "admin", "manager", "sales", "data_entry"];
const approvers = ["owner", "admin", "manager"];

function roundMoney(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export async function createSalesDocument(formData: FormData): Promise<void> {
  const customerId = String(formData.get("customerId") ?? "").trim();
  const documentType = String(formData.get("documentType") ?? "proforma");
  const issueDate = String(formData.get("issueDate") ?? "").trim();
  const validUntil = String(formData.get("validUntil") ?? "").trim();
  const vatTreatment = String(formData.get("vatTreatment") ?? "exclusive");
  const terms = String(formData.get("terms") ?? "").trim();

  if (!customerId || !["quotation", "proforma", "sales_order"].includes(documentType)) return;
  if (!["exclusive", "inclusive", "none"].includes(vatTreatment)) return;
  if (issueDate && !/^\d{4}-\d{2}-\d{2}$/.test(issueDate)) return;
  if (validUntil && !/^\d{4}-\d{2}-\d{2}$/.test(validUntil)) return;
  if (issueDate && validUntil && validUntil < issueDate) return;

  const descriptions = formData.getAll("description").map(v => String(v).trim());
  const quantities = formData.getAll("quantity").map(v => String(v).trim());
  const units = formData.getAll("unitOfMeasure").map(v => String(v).trim());
  const prices = formData.getAll("unitPrice").map(v => String(v).trim());
  const discounts = formData.getAll("discountAmount").map(v => String(v).trim());
  const landedCosts = formData.getAll("landedUnitCost").map(v => String(v).trim());
  const landedReferences = formData.getAll("landedCostReference").map(v => String(v).trim());

  const lines: Array<{
    description: string; quantity: number; unit_of_measure: string; unit_price: number;
    discount_amount: number; line_net: number; landed_unit_cost: number | null; landed_cost_reference: string | null;
  }> = [];
  let hasInvalidLine = false;

  descriptions.forEach((description, index) => {
    const quantityInput = quantities[index] ?? "";
    const priceInput = prices[index] ?? "";
    const discountInput = discounts[index] ?? "";
    const landedInput = landedCosts[index] ?? "";
    if (!description) {
      if (quantityInput || priceInput || (discountInput && discountInput !== "0") || landedInput) hasInvalidLine = true;
      return;
    }
    const quantity = Number(quantityInput);
    const unitPrice = Number(priceInput);
    const discount = Number(discountInput || 0);
    const landedCost = landedInput ? Number(landedInput) : null;
    if (description.length > 240 || !Number.isFinite(quantity) || quantity <= 0 || quantity > 1_000_000) { hasInvalidLine = true; return; }
    if (!Number.isFinite(unitPrice) || unitPrice < 0 || unitPrice > 1_000_000_000) { hasInvalidLine = true; return; }
    if (!Number.isFinite(discount) || discount < 0) { hasInvalidLine = true; return; }
    if (discount > roundMoney(quantity * unitPrice)) { hasInvalidLine = true; return; }
    if (landedCost !== null && (!Number.isFinite(landedCost) || landedCost < 0 || landedCost > 1_000_000_000)) { hasInvalidLine = true; return; }
    lines.push({
      description,
      quantity,
      unit_of_measure: units[index]?.slice(0, 30) || "pcs",
      unit_price: roundMoney(unitPrice),
      discount_amount: roundMoney(discount),
      line_net: roundMoney(quantity * unitPrice - discount),
      landed_unit_cost: landedCost === null ? null : roundMoney(landedCost),
      landed_cost_reference: landedReferences[index]?.trim().slice(0, 160) || null
    });
  });

  if (hasInvalidLine || lines.length === 0 || lines.length > 12) return;

  const context = await getCompanyContext();
  if (!salesWriters.includes(context.active.role)) return;

  const subtotal = roundMoney(lines.reduce((sum, line) => sum + line.quantity * line.unit_price, 0));
  const discountTotal = roundMoney(lines.reduce((sum, line) => sum + line.discount_amount, 0));
  const taxableBase = roundMoney(subtotal - discountTotal);
  const vatRateBps = 1500;
  let vatTotal = 0;
  let grandTotal = taxableBase;
  if (vatTreatment === "exclusive") {
    vatTotal = roundMoney(taxableBase * vatRateBps / 10000);
    grandTotal = roundMoney(taxableBase + vatTotal);
  } else if (vatTreatment === "inclusive") {
    const net = roundMoney(taxableBase / (1 + vatRateBps / 10000));
    vatTotal = roundMoney(taxableBase - net);
    grandTotal = taxableBase;
  }

  const prefix = documentType === "quotation" ? "QUO" : documentType === "sales_order" ? "SO" : "PRO";
  const documentNumber = `${prefix}-${new Date().toISOString().slice(0,10).replaceAll("-", "")}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;

  const { data: document, error: documentError } = await context.supabase
    .from("sales_documents")
    .insert({
      company_id: context.active.companyId,
      document_number: documentNumber,
      customer_id: customerId,
      document_type: documentType,
      status: "submitted",
      issue_date: issueDate || new Date().toISOString().slice(0,10),
      valid_until: validUntil || null,
      currency_code: "ETB",
      subtotal,
      discount_total: discountTotal,
      vat_treatment: vatTreatment,
      vat_rate_bps: vatRateBps,
      vat_total: vatTotal,
      grand_total: grandTotal,
      terms: terms || null,
      created_by: context.user.id
    })
    .select("id")
    .single();

  if (documentError || !document) redirect("/sales?error=create");

  const lineRows = lines.map(line => ({
    ...line,
    company_id: context.active.companyId,
    sales_document_id: document.id
  }));
  const { error: lineError } = await context.supabase.from("sales_document_lines").insert(lineRows);

  if (lineError) {
    await context.supabase.from("sales_documents")
      .delete().eq("id", document.id).eq("company_id", context.active.companyId);
    redirect("/sales?error=lines");
  }

  revalidatePath("/sales");
  revalidatePath("/profitability");
  revalidatePath("/");
  redirect("/sales?created=1");
}

export async function approveSalesDocument(formData: FormData): Promise<void> {
  const documentId = String(formData.get("documentId") ?? "").trim();
  if (!documentId) return;

  const context = await getCompanyContext();
  if (!approvers.includes(context.active.role)) return;

  await context.supabase.from("sales_documents")
    .update({
      status: "approved",
      approved_by: context.user.id,
      approved_at: new Date().toISOString()
    })
    .eq("id", documentId)
    .eq("company_id", context.active.companyId)
    .eq("status", "submitted");

  revalidatePath("/sales");
  revalidatePath("/profitability");
}

export async function addSalesDirectCost(formData: FormData): Promise<void> {
  const salesDocumentId = String(formData.get("salesDocumentId") ?? "").trim();
  const category = String(formData.get("category") ?? "");
  const description = String(formData.get("description") ?? "").trim();
  const amount = Number(formData.get("amount"));
  const vatTreatment = String(formData.get("vatTreatment") ?? "none");
  const recoverableVat = String(formData.get("recoverableVat") ?? "") === "on";
  const incurredOn = String(formData.get("incurredOn") ?? "").trim();

  if (!salesDocumentId || !["transportation", "loading", "miscellaneous"].includes(category)) return;
  if (description.length < 2 || description.length > 240 || !Number.isFinite(amount) || amount <= 0) return;
  if (!["exclusive", "inclusive", "none"].includes(vatTreatment)) return;
  if (incurredOn && !/^\d{4}-\d{2}-\d{2}$/.test(incurredOn)) return;

  const context = await getCompanyContext();
  if (!salesWriters.includes(context.active.role)) return;

  await context.supabase.from("direct_costs").insert({
    company_id: context.active.companyId,
    sales_document_id: salesDocumentId,
    category,
    description,
    amount: roundMoney(amount),
    vat_treatment: vatTreatment,
    vat_rate_bps: 1500,
    recoverable_vat: recoverableVat,
    incurred_on: incurredOn || new Date().toISOString().slice(0,10),
    created_by: context.user.id
  });

  revalidatePath("/sales");
  revalidatePath("/profitability");
}
