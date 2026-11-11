"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";

const purchasingWriters = ["owner", "admin", "manager", "purchasing", "data_entry"];
const approvers = ["owner", "admin", "manager"];

function roundMoney(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export async function createSupplier(formData: FormData): Promise<void> {
  const legalName = String(formData.get("legalName") ?? "").trim();
  const contactName = String(formData.get("contactName") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const taxNumber = String(formData.get("taxNumber") ?? "").trim();
  const address = String(formData.get("address") ?? "").trim();
  if (legalName.length < 2 || legalName.length > 200) return;
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return;

  const context = await getCompanyContext();
  if (!purchasingWriters.includes(context.active.role)) return;

  await context.supabase.from("suppliers").insert({
    company_id: context.active.companyId,
    legal_name: legalName,
    contact_name: contactName || null,
    phone: phone || null,
    email: email || null,
    tax_number: taxNumber || null,
    address: address || null,
    created_by: context.user.id
  });
  revalidatePath("/purchasing");
}

export async function createProduct(formData: FormData): Promise<void> {
  const name = String(formData.get("name") ?? "").trim();
  const sku = String(formData.get("sku") ?? "").trim();
  const unit = String(formData.get("unitOfMeasure") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const purchasePriceInput = String(formData.get("purchasePrice") ?? "").trim();
  const purchasePrice = purchasePriceInput ? Number(purchasePriceInput) : null;

  if (name.length < 2 || name.length > 180 || !unit || unit.length > 30) return;
  if (purchasePrice !== null && (!Number.isFinite(purchasePrice) || purchasePrice < 0)) return;

  const context = await getCompanyContext();
  if (!["owner", "admin", "manager", "purchasing", "sales", "data_entry"].includes(context.active.role)) return;
  if (purchasePrice !== null && !purchasingWriters.includes(context.active.role)) return;

  const { data: product, error } = await context.supabase.from("products").insert({
    company_id: context.active.companyId,
    name,
    sku: sku || null,
    unit_of_measure: unit,
    description: description || null,
    created_by: context.user.id
  }).select("id").single();

  if (error || !product) redirect("/purchasing?error=product");

  if (purchasePrice !== null) {
    const { error: priceError } = await context.supabase.from("product_prices").insert({
      company_id: context.active.companyId,
      product_id: product.id,
      price_type: "purchase",
      unit_price: roundMoney(purchasePrice),
      currency_code: "ETB",
      vat_treatment: "exclusive",
      vat_rate_bps: context.active.vatRateBps,
      created_by: context.user.id
    });
    if (priceError) {
      await context.supabase.from("products").delete().eq("id", product.id).eq("company_id", context.active.companyId);
      redirect("/purchasing?error=price");
    }
  }
  revalidatePath("/purchasing");
  revalidatePath("/sales");
}

export async function recordProductPrice(formData: FormData): Promise<void> {
  const productId = String(formData.get("productId") ?? "").trim();
  const priceType = String(formData.get("priceType") ?? "");
  const supplierId = String(formData.get("supplierId") ?? "").trim();
  const unitPrice = Number(formData.get("unitPrice"));
  const vatTreatment = String(formData.get("vatTreatment") ?? "exclusive");
  const effectiveFrom = String(formData.get("effectiveFrom") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (!productId || !["purchase", "sales"].includes(priceType)) return;
  if (priceType === "sales" && supplierId) return;
  if (!Number.isFinite(unitPrice) || unitPrice < 0 || !["exclusive", "inclusive", "none"].includes(vatTreatment)) return;
  if (effectiveFrom && !/^\d{4}-\d{2}-\d{2}$/.test(effectiveFrom)) return;

  const context = await getCompanyContext();
  const allowed = priceType === "purchase"
    ? ["owner", "admin", "manager", "purchasing", "data_entry"].includes(context.active.role)
    : ["owner", "admin", "manager", "sales"].includes(context.active.role);
  if (!allowed) return;

  await context.supabase.from("product_prices").insert({
    company_id: context.active.companyId,
    product_id: productId,
    supplier_id: supplierId || null,
    price_type: priceType,
    unit_price: roundMoney(unitPrice),
    currency_code: "ETB",
    vat_treatment: vatTreatment,
    vat_rate_bps: context.active.vatRateBps,
    effective_from: effectiveFrom || new Date().toISOString().slice(0,10),
    notes: notes || null,
    created_by: context.user.id
  });
  revalidatePath("/purchasing");
  revalidatePath("/sales");
}

export async function createPurchaseRequest(formData: FormData): Promise<void> {
  const supplierId = String(formData.get("supplierId") ?? "").trim();
  const requestedDate = String(formData.get("requestedDate") ?? "").trim();
  const requiredBy = String(formData.get("requiredBy") ?? "").trim();
  const reason = String(formData.get("reason") ?? "").trim();
  const descriptions = formData.getAll("description").map(v => String(v).trim());
  const quantities = formData.getAll("quantity").map(v => Number(v));
  const units = formData.getAll("unitOfMeasure").map(v => String(v).trim());
  const estimates = formData.getAll("estimatedUnitPrice").map(v => String(v).trim());

  if (requestedDate && !/^\d{4}-\d{2}-\d{2}$/.test(requestedDate)) return;
  if (requiredBy && !/^\d{4}-\d{2}-\d{2}$/.test(requiredBy)) return;
  if (requestedDate && requiredBy && requiredBy < requestedDate) return;

  const lines = descriptions.map((description, i) => ({
    description,
    requested_quantity: quantities[i],
    unit_of_measure: units[i] || "pcs",
    estimated_unit_price: estimates[i] ? Number(estimates[i]) : null
  })).filter(line => line.description);

  if (!lines.length || lines.length > 12 || lines.some(line =>
    line.description.length > 240 || !Number.isFinite(line.requested_quantity) || line.requested_quantity <= 0 ||
    line.unit_of_measure.length > 30 ||
    (line.estimated_unit_price !== null && (!Number.isFinite(line.estimated_unit_price) || line.estimated_unit_price < 0))
  )) return;

  const context = await getCompanyContext();
  if (!purchasingWriters.includes(context.active.role)) return;

  const requestNumber = `PR-${new Date().toISOString().slice(0,10).replaceAll("-", "")}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
  const { data: request, error } = await context.supabase.from("purchase_requests").insert({
    company_id: context.active.companyId,
    request_number: requestNumber,
    supplier_id: supplierId || null,
    requested_date: requestedDate || new Date().toISOString().slice(0,10),
    required_by: requiredBy || null,
    status: "submitted",
    reason: reason || null,
    requested_by: context.user.id
  }).select("id").single();

  if (error || !request) redirect("/purchasing?error=request");
  const { error: lineError } = await context.supabase.from("purchase_request_lines").insert(lines.map(line => ({
    ...line,
    company_id: context.active.companyId,
    purchase_request_id: request.id
  })));
  if (lineError) {
    await context.supabase.from("purchase_requests").delete().eq("id", request.id).eq("company_id", context.active.companyId);
    redirect("/purchasing?error=request-lines");
  }
  revalidatePath("/purchasing");
  redirect("/purchasing?request=created");
}

export async function createPurchaseOrder(formData: FormData): Promise<void> {
  const supplierId=String(formData.get("supplierId")??"").trim();
  const orderDate=String(formData.get("orderDate")??"").trim();
  const expectedDate=String(formData.get("expectedDate")??"").trim();
  const vatTreatment=String(formData.get("vatTreatment")??"exclusive");
  const notes=String(formData.get("notes")??"").trim();

  if(!supplierId||!["exclusive","inclusive","none"].includes(vatTreatment))return;
  if(orderDate&&!/^\d{4}-\d{2}-\d{2}$/.test(orderDate))return;
  if(expectedDate&&!/^\d{4}-\d{2}-\d{2}$/.test(expectedDate))return;
  if(orderDate&&expectedDate&&expectedDate<orderDate)return;

  const context=await getCompanyContext();
  if(!purchasingWriters.includes(context.active.role))return;

  const descriptions=formData.getAll("description").map(v=>String(v).trim());
  const quantities=formData.getAll("quantity").map(v=>String(v).trim());
  const units=formData.getAll("unitOfMeasure").map(v=>String(v).trim());
  const prices=formData.getAll("unitPrice").map(v=>String(v).trim());
  const productIds=formData.getAll("productId").map(v=>String(v).trim());
  const selectedProductIds=[...new Set(productIds.filter(Boolean))];
  const productMap=new Map<string,{name:string;unit_of_measure:string}>();
  const currentPrices=new Map<string,{unit_price:number;vat_treatment:string}>();

  if(selectedProductIds.length){
    const [{data:productRows},{data:priceRows}]=await Promise.all([
      context.supabase.from("products").select("id,name,unit_of_measure").eq("company_id",context.active.companyId).eq("is_active",true).in("id",selectedProductIds),
      context.supabase.from("product_prices").select("product_id,supplier_id,unit_price,vat_treatment,effective_from").eq("company_id",context.active.companyId).eq("price_type","purchase").in("product_id",selectedProductIds).lte("effective_from",orderDate||new Date().toISOString().slice(0,10)).order("effective_from",{ascending:false}).limit(2000)
    ]);
    for(const product of productRows??[])productMap.set(product.id,{name:product.name,unit_of_measure:product.unit_of_measure});
    for(const price of priceRows??[]){
      const key=`${price.product_id}:${price.supplier_id||"general"}`;
      if(!currentPrices.has(key))currentPrices.set(key,{unit_price:Number(price.unit_price),vat_treatment:price.vat_treatment});
    }
  }

  const lines:Array<{product_id:string|null;description:string;quantity:number;unit_of_measure:string;unit_price:number;line_net:number}>=[];
  let invalid=false;
  descriptions.forEach((descriptionInput,index)=>{
    const productId=productIds[index]||"";
    const product=productId?productMap.get(productId):undefined;
    const description=descriptionInput||product?.name||"";
    const quantityInput=quantities[index]??"";
    const priceInput=prices[index]??"";
    if(!description&&!productId){
      if(quantityInput||priceInput)invalid=true;
      return;
    }
    if(productId&&!product){invalid=true;return;}
    const supplierPrice=productId?currentPrices.get(`${productId}:${supplierId}`):undefined;
    const generalPrice=productId?currentPrices.get(`${productId}:general`):undefined;
    const suggestedPrice=[supplierPrice,generalPrice].find(price=>price?.vat_treatment===vatTreatment);
    const quantity=Number(quantityInput);
    const unitPrice=priceInput?Number(priceInput):suggestedPrice?.unit_price??Number.NaN;
    if(description.length>240||!Number.isFinite(quantity)||quantity<=0||quantity>1_000_000||!Number.isFinite(unitPrice)||unitPrice<0||unitPrice>1_000_000_000){invalid=true;return;}
    lines.push({
      product_id:productId||null,
      description,
      quantity,
      unit_of_measure:units[index]?.slice(0,30)||product?.unit_of_measure||"pcs",
      unit_price:roundMoney(unitPrice),
      line_net:roundMoney(quantity*unitPrice)
    });
  });

  if(invalid||!lines.length||lines.length>12)return;

  const subtotal=roundMoney(lines.reduce((sum,line)=>sum+line.line_net,0));
  const vatRateBps=context.active.vatRateBps;
  let vatTotal=0;
  let grandTotal=subtotal;
  if(vatTreatment==="exclusive"){
    vatTotal=roundMoney(subtotal*vatRateBps/10000);
    grandTotal=roundMoney(subtotal+vatTotal);
  }else if(vatTreatment==="inclusive"){
    const net=roundMoney(subtotal/(1+vatRateBps/10000));
    vatTotal=roundMoney(subtotal-net);
  }

  const orderNumber=`PO-${new Date().toISOString().slice(0,10).replaceAll("-","")}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
  const {data:order,error}=await context.supabase.from("purchase_orders").insert({
    company_id:context.active.companyId,
    order_number:orderNumber,
    supplier_id:supplierId,
    status:"submitted",
    order_date:orderDate||new Date().toISOString().slice(0,10),
    expected_date:expectedDate||null,
    currency_code:"ETB",
    subtotal,
    vat_treatment:vatTreatment,
    vat_rate_bps:vatRateBps,
    vat_total:vatTotal,
    grand_total:grandTotal,
    notes:notes||null,
    created_by:context.user.id
  }).select("id").single();

  if(error||!order)redirect("/purchasing?error=order");
  const {error:lineError}=await context.supabase.from("purchase_order_lines").insert(lines.map(line=>({...line,company_id:context.active.companyId,purchase_order_id:order.id})));
  if(lineError){
    await context.supabase.from("purchase_orders").delete().eq("id",order.id).eq("company_id",context.active.companyId);
    redirect("/purchasing?error=order-lines");
  }
  revalidatePath("/purchasing");
  revalidatePath("/profitability");
  redirect("/purchasing?order=created");
}

export async function approvePurchaseOrder(formData: FormData): Promise<void> {
  const orderId = String(formData.get("orderId") ?? "").trim();
  if (!orderId) return;
  const context = await getCompanyContext();
  if (!approvers.includes(context.active.role)) return;

  await context.supabase.from("purchase_orders").update({
    status: "approved",
    approved_by: context.user.id,
    approved_at: new Date().toISOString()
  }).eq("id", orderId).eq("company_id", context.active.companyId).eq("status", "submitted");
  revalidatePath("/purchasing");
}

export async function addPurchaseDirectCost(formData: FormData): Promise<void> {
  const purchaseOrderId = String(formData.get("purchaseOrderId") ?? "").trim();
  const category = String(formData.get("category") ?? "");
  const description = String(formData.get("description") ?? "").trim();
  const amount = Number(formData.get("amount"));
  const vatTreatment = String(formData.get("vatTreatment") ?? "none");
  const recoverableVat = String(formData.get("recoverableVat") ?? "") === "on";

  if (!purchaseOrderId || !["transportation", "loading", "miscellaneous"].includes(category)) return;
  if (description.length < 2 || description.length > 240 || !Number.isFinite(amount) || amount <= 0) return;
  if (!["exclusive", "inclusive", "none"].includes(vatTreatment)) return;
  const context = await getCompanyContext();
  if (!purchasingWriters.includes(context.active.role)) return;

  await context.supabase.from("direct_costs").insert({
    company_id: context.active.companyId,
    purchase_order_id: purchaseOrderId,
    category,
    description,
    amount: roundMoney(amount),
    vat_treatment: vatTreatment,
    vat_rate_bps: context.active.vatRateBps,
    recoverable_vat: recoverableVat,
    created_by: context.user.id
  });
  revalidatePath("/purchasing");
  revalidatePath("/profitability");
}

export async function approvePurchaseRequest(formData: FormData): Promise<void> {
  const requestId = String(formData.get("requestId") ?? "").trim();
  if (!requestId) return;
  const context = await getCompanyContext();
  if (!approvers.includes(context.active.role)) return;

  await context.supabase.from("purchase_requests").update({
    status: "approved",
    approved_by: context.user.id,
    approved_at: new Date().toISOString()
  }).eq("id", requestId).eq("company_id", context.active.companyId).eq("status", "submitted");
  revalidatePath("/purchasing");
}

export async function convertPurchaseRequestToOrder(formData: FormData): Promise<void> {
  const requestId=String(formData.get("requestId")??"").trim();
  const supplierIdInput=String(formData.get("supplierId")??"").trim();
  const vatTreatment=String(formData.get("vatTreatment")??"exclusive");
  if(!requestId||!["exclusive","inclusive","none"].includes(vatTreatment))return;

  const context=await getCompanyContext();
  if(!["owner","admin","manager","purchasing"].includes(context.active.role))return;

  const {data:request}=await context.supabase.from("purchase_requests")
    .select("id,request_number,status,supplier_id,required_by,reason")
    .eq("id",requestId).eq("company_id",context.active.companyId).eq("status","approved").maybeSingle();
  if(!request)redirect("/purchasing?error=request-not-approved");

  const supplierId=request.supplier_id||supplierIdInput;
  if(!supplierId)redirect("/purchasing?error=request-supplier");
  const [{data:supplier},{data:requestLines},{data:existingOrder}]=await Promise.all([
    context.supabase.from("suppliers").select("id").eq("id",supplierId).eq("company_id",context.active.companyId).maybeSingle(),
    context.supabase.from("purchase_request_lines").select("id,product_id,description,requested_quantity,unit_of_measure,estimated_unit_price").eq("purchase_request_id",request.id).eq("company_id",context.active.companyId).order("created_at"),
    context.supabase.from("purchase_orders").select("id,order_number").eq("purchase_request_id",request.id).eq("company_id",context.active.companyId).maybeSingle()
  ]);
  if(!supplier)redirect("/purchasing?error=request-supplier");
  if(existingOrder){
    const {error:repairError}=await context.supabase.from("purchase_requests")
      .update({status:"converted"})
      .eq("id",request.id).eq("company_id",context.active.companyId).eq("status","approved");
    if(repairError)redirect(`/purchasing?error=convert-status&order=${encodeURIComponent(existingOrder.order_number)}`);
    revalidatePath("/purchasing");
    redirect(`/purchasing?converted=${encodeURIComponent(existingOrder.order_number)}`);
  }
  if(!requestLines?.length||requestLines.some(line=>line.estimated_unit_price===null))redirect("/purchasing?error=request-estimates");

  const lines=requestLines.map(line=>({
    product_id:line.product_id,
    description:line.description,
    quantity:Number(line.requested_quantity),
    unit_of_measure:line.unit_of_measure,
    unit_price:roundMoney(Number(line.estimated_unit_price)),
    line_net:roundMoney(Number(line.requested_quantity)*Number(line.estimated_unit_price))
  }));
  const subtotal=roundMoney(lines.reduce((sum,line)=>sum+line.line_net,0));
  const vatRateBps=context.active.vatRateBps;
  let vatTotal=0;
  let grandTotal=subtotal;
  if(vatTreatment==="exclusive"){
    vatTotal=roundMoney(subtotal*vatRateBps/10000);
    grandTotal=roundMoney(subtotal+vatTotal);
  }else if(vatTreatment==="inclusive"){
    const net=roundMoney(subtotal/(1+vatRateBps/10000));
    vatTotal=roundMoney(subtotal-net);
  }

  const orderNumber=`PO-${new Date().toISOString().slice(0,10).replaceAll("-","")}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
  const {data:order,error}=await context.supabase.from("purchase_orders").insert({
    company_id:context.active.companyId,
    order_number:orderNumber,
    supplier_id:supplierId,
    purchase_request_id:request.id,
    status:"submitted",
    order_date:new Date().toISOString().slice(0,10),
    expected_date:request.required_by,
    currency_code:"ETB",
    subtotal,
    vat_treatment:vatTreatment,
    vat_rate_bps:vatRateBps,
    vat_total:vatTotal,
    grand_total:grandTotal,
    notes:`Converted from ${request.request_number}. ${request.reason||""}`.trim(),
    created_by:context.user.id
  }).select("id").single();
  if(error||!order)redirect("/purchasing?error=convert-order");

  const {error:lineError}=await context.supabase.from("purchase_order_lines").insert(lines.map(line=>({
    ...line,
    company_id:context.active.companyId,
    purchase_order_id:order.id
  })));
  if(lineError){
    await context.supabase.from("purchase_orders").delete().eq("id",order.id).eq("company_id",context.active.companyId);
    redirect("/purchasing?error=convert-lines");
  }

  const {error:requestError}=await context.supabase.from("purchase_requests")
    .update({status:"converted"})
    .eq("id",request.id).eq("company_id",context.active.companyId).eq("status","approved");
  if(requestError)redirect(`/purchasing?error=convert-status&order=${encodeURIComponent(orderNumber)}`);

  revalidatePath("/purchasing");
  revalidatePath("/profitability");
  redirect(`/purchasing?converted=${encodeURIComponent(orderNumber)}`);
}

export async function updatePurchaseRequestEstimate(formData: FormData): Promise<void> {
  const requestId=String(formData.get("requestId")??"").trim();
  const lineId=String(formData.get("lineId")??"").trim();
  const priceInput=String(formData.get("estimatedUnitPrice")??"").trim();
  const price=Number(priceInput);
  if(!requestId||!lineId||!priceInput||!Number.isFinite(price)||price<0)return;

  const context=await getCompanyContext();
  if(!["owner","admin","manager","purchasing"].includes(context.active.role))return;

  const [{data:request},{data:line}]=await Promise.all([
    context.supabase.from("purchase_requests").select("id,status").eq("id",requestId).eq("company_id",context.active.companyId).in("status",["submitted","approved"]).maybeSingle(),
    context.supabase.from("purchase_request_lines").select("id").eq("id",lineId).eq("purchase_request_id",requestId).eq("company_id",context.active.companyId).maybeSingle()
  ]);
  if(!request||!line)return;

  const {error}=await context.supabase.from("purchase_request_lines")
    .update({estimated_unit_price:roundMoney(price)})
    .eq("id",lineId).eq("purchase_request_id",requestId).eq("company_id",context.active.companyId);
  if(error)redirect("/purchasing?error=estimate");
  revalidatePath("/purchasing");
  redirect("/purchasing?estimated=1");
}
