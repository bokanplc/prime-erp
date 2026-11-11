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

  const lines = descriptions.map((description, index) => {
    const quantity = Number(quantities[index]);
    const unitPrice = Number(prices[index]);
    const discount = Number(discounts[index] || 0);
    if (!description) return null;
    if (description.length > 240 || !Number.isFinite(quantity) || quantity <= 0 || quantity > 1_000_000) return null;
    if (!Number.isFinite(unitPrice) || unitPrice < 0 || unitPrice > 1_000_000_000) return null;
    if (!Number.isFinite(discount) || discount < 0) return null;
    const gross = roundMoney(quantity * unitPrice);
    if (discount > gross) return null;
    return {
      description,
      quantity,
      unit_of_measure: units[index]?.slice(0, 30) || "pcs",
      unit_price: roundMoney(unitPrice),
      discount_amount: roundMoney(discount),
      line_net: roundMoney(gross - discount)
    };
  }).filter((line): line is NonNullable<typeof line> => line !== null);

  const hasInvalidPopulatedLine = descriptions.some((description, index) =>
    Boolean(description) && !lines.some(line => line.description === description && line.quantity === Number(quantities[index]))
  );
  if (hasInvalidPopulatedLine || lines.length === 0 || lines.length > 12) return;

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
