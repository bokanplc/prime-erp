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

  const context = await getCompanyContext();
  if (!salesWriters.includes(context.active.role)) return;

  const descriptions = formData.getAll("description").map(v => String(v).trim());
  const quantities = formData.getAll("quantity").map(v => String(v).trim());
  const units = formData.getAll("unitOfMeasure").map(v => String(v).trim());
  const prices = formData.getAll("unitPrice").map(v => String(v).trim());
  const discounts = formData.getAll("discountAmount").map(v => String(v).trim());
  const productIds = formData.getAll("productId").map(v => String(v).trim());
  const landedCosts = formData.getAll("landedUnitCost").map(v => String(v).trim());
  const landedReferences = formData.getAll("landedCostReference").map(v => String(v).trim());
  const landedPurchaseLines = formData.getAll("landedPurchaseOrderLineId").map(v => String(v).trim());

  const selectedProductIds = [...new Set(productIds.filter(Boolean))];
  const selectedPurchaseLineIds = [...new Set(landedPurchaseLines.filter(Boolean))];
  const approvedPurchaseLineIds = new Set<string>();
  if (selectedPurchaseLineIds.length) {
    const {data:sourceLines} = await context.supabase.from("purchase_order_lines")
      .select("id,purchase_order_id")
      .eq("company_id",context.active.companyId)
      .in("id",selectedPurchaseLineIds);
    const sourceOrderIds = [...new Set((sourceLines??[]).map(line=>line.purchase_order_id))];
    const {data:sourceOrders} = sourceOrderIds.length
      ? await context.supabase.from("purchase_orders").select("id").eq("company_id",context.active.companyId).in("id",sourceOrderIds).in("status",["approved","sent","accepted"])
      : {data:[]};
    const approvedOrderIds = new Set((sourceOrders??[]).map(order=>order.id));
    for (const line of sourceLines??[]) if (approvedOrderIds.has(line.purchase_order_id)) approvedPurchaseLineIds.add(line.id);
  }
  const productMap = new Map<string, {name:string;unit_of_measure:string}>();
  const currentPriceMap = new Map<string, {unit_price:number;vat_treatment:string}>();
  if (selectedProductIds.length) {
    const [{data:products},{data:priceRows}] = await Promise.all([
      context.supabase.from("products").select("id,name,unit_of_measure").eq("company_id",context.active.companyId).in("id",selectedProductIds).eq("is_active",true),
      context.supabase.from("product_prices").select("product_id,customer_id,unit_price,vat_treatment,effective_from").eq("company_id",context.active.companyId).eq("price_type","sales").in("product_id",selectedProductIds).lte("effective_from",issueDate||new Date().toISOString().slice(0,10)).order("effective_from",{ascending:false}).limit(2000)
    ]);
    for (const product of products??[]) productMap.set(product.id,{name:product.name,unit_of_measure:product.unit_of_measure});
    for (const price of priceRows??[]) {
      const key = `${price.product_id}:${price.customer_id||"general"}`;
      if (!currentPriceMap.has(key)) currentPriceMap.set(key,{unit_price:Number(price.unit_price),vat_treatment:price.vat_treatment});
    }
  }

  const lines: Array<{
    product_id:string|null;description:string;quantity:number;unit_of_measure:string;unit_price:number;
    discount_amount:number;line_net:number;landed_unit_cost:number|null;landed_cost_reference:string|null;
    landed_purchase_order_line_id:string|null;
  }> = [];
  let hasInvalidLine = false;

  descriptions.forEach((descriptionInput,index) => {
    const productId=productIds[index]||"";
    const product=productId?productMap.get(productId):undefined;
    const description=descriptionInput||product?.name||"";
    const quantityInput=quantities[index]??"";
    const priceInput=prices[index]??"";
    const discountInput=discounts[index]??"";
    const landedInput=landedCosts[index]??"";
    if (!description && !productId) {
      if (quantityInput || priceInput || (discountInput&&discountInput!=="0") || landedInput || landedPurchaseLines[index]) hasInvalidLine=true;
      return;
    }
    if (productId&&!product) { hasInvalidLine=true; return; }
    if (landedPurchaseLines[index]&&!approvedPurchaseLineIds.has(landedPurchaseLines[index])) { hasInvalidLine=true; return; }
    const quantity=Number(quantityInput);
    const customerPrice=productId?currentPriceMap.get(`${productId}:${customerId}`):undefined;
    const generalPrice=productId?currentPriceMap.get(`${productId}:general`):undefined;
    const suggestedPrice=[customerPrice,generalPrice].find(price=>price?.vat_treatment===vatTreatment);
    const unitPrice=priceInput?Number(priceInput):suggestedPrice?.unit_price??Number.NaN;
    const discount=Number(discountInput||0);
    const landedCost=landedInput?Number(landedInput):null;
    if (description.length>240 || !Number.isFinite(quantity) || quantity<=0 || quantity>1_000_000) {hasInvalidLine=true;return;}
    if (!Number.isFinite(unitPrice) || unitPrice<0 || unitPrice>1_000_000_000) {hasInvalidLine=true;return;}
    if (!Number.isFinite(discount) || discount<0 || discount>roundMoney(quantity*unitPrice)) {hasInvalidLine=true;return;}
    if (landedCost!==null&&(!Number.isFinite(landedCost)||landedCost<0||landedCost>1_000_000_000)) {hasInvalidLine=true;return;}
    lines.push({
      product_id:productId||null,
      description,
      quantity,
      unit_of_measure:units[index]?.slice(0,30)||product?.unit_of_measure||"pcs",
      unit_price:roundMoney(unitPrice),
      discount_amount:roundMoney(discount),
      line_net:roundMoney(quantity*unitPrice-discount),
      landed_unit_cost:landedCost===null?null:roundMoney(landedCost),
      landed_cost_reference:landedReferences[index]?.trim().slice(0,160)||null,
      landed_purchase_order_line_id:landedPurchaseLines[index]||null
    });
  });

  if (hasInvalidLine || lines.length===0 || lines.length>12) return;

  const subtotal=roundMoney(lines.reduce((sum,line)=>sum+line.quantity*line.unit_price,0));
  const discountTotal=roundMoney(lines.reduce((sum,line)=>sum+line.discount_amount,0));
  const taxableBase=roundMoney(subtotal-discountTotal);
  const vatRateBps=context.active.vatRateBps;
  let vatTotal=0;
  let grandTotal=taxableBase;
  if(vatTreatment==="exclusive"){
    vatTotal=roundMoney(taxableBase*vatRateBps/10000);
    grandTotal=roundMoney(taxableBase+vatTotal);
  }else if(vatTreatment==="inclusive"){
    const net=roundMoney(taxableBase/(1+vatRateBps/10000));
    vatTotal=roundMoney(taxableBase-net);
  }

  const prefix=documentType==="quotation"?"QUO":documentType==="sales_order"?"SO":"PRO";
  const documentNumber=`${prefix}-${new Date().toISOString().slice(0,10).replaceAll("-","")}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
  const {data:document,error:documentError}=await context.supabase.from("sales_documents").insert({
    company_id:context.active.companyId,
    document_number:documentNumber,
    customer_id:customerId,
    document_type:documentType,
    status:"submitted",
    issue_date:issueDate||new Date().toISOString().slice(0,10),
    valid_until:validUntil||null,
    currency_code:"ETB",
    subtotal,
    discount_total:discountTotal,
    vat_treatment:vatTreatment,
    vat_rate_bps:vatRateBps,
    vat_total:vatTotal,
    grand_total:grandTotal,
    terms:terms||null,
    created_by:context.user.id
  }).select("id").single();

  if(documentError||!document)redirect("/sales?error=create");
  const lineRows=lines.map(line=>({...line,company_id:context.active.companyId,sales_document_id:document.id}));
  const {error:lineError}=await context.supabase.from("sales_document_lines").insert(lineRows);
  if(lineError){
    await context.supabase.from("sales_documents").delete().eq("id",document.id).eq("company_id",context.active.companyId);
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
    vat_rate_bps: context.active.vatRateBps,
    recoverable_vat: recoverableVat,
    incurred_on: incurredOn || new Date().toISOString().slice(0,10),
    created_by: context.user.id
  });

  revalidatePath("/sales");
  revalidatePath("/profitability");
}

export async function recordSalesPrice(formData: FormData): Promise<void> {
  const productId = String(formData.get("productId") ?? "").trim();
  const customerId = String(formData.get("customerId") ?? "").trim();
  const unitPrice = Number(formData.get("unitPrice"));
  const vatTreatment = String(formData.get("vatTreatment") ?? "exclusive");
  const effectiveFrom = String(formData.get("effectiveFrom") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (!productId || !Number.isFinite(unitPrice) || unitPrice < 0) return;
  if (!["exclusive", "inclusive", "none"].includes(vatTreatment)) return;
  if (effectiveFrom && !/^\d{4}-\d{2}-\d{2}$/.test(effectiveFrom)) return;

  const context = await getCompanyContext();
  if (!["owner", "admin", "manager", "sales"].includes(context.active.role)) return;

  await context.supabase.from("product_prices").insert({
    company_id: context.active.companyId,
    product_id: productId,
    customer_id: customerId || null,
    price_type: "sales",
    unit_price: roundMoney(unitPrice),
    currency_code: "ETB",
    vat_treatment: vatTreatment,
    vat_rate_bps: context.active.vatRateBps,
    effective_from: effectiveFrom || new Date().toISOString().slice(0,10),
    notes: notes || null,
    created_by: context.user.id
  });
  revalidatePath("/sales");
}
