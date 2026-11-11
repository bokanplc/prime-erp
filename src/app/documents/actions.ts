"use server";

import { revalidatePath } from "next/cache";
import { getCompanyContext } from "@/lib/auth/company-context";

const allowedTypes = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
]);

export async function registerDocument(formData: FormData): Promise<{ok:boolean;message:string}> {
  const storagePath=String(formData.get("storagePath")??"").trim();
  const fileName=String(formData.get("fileName")??"").trim();
  const contentType=String(formData.get("contentType")??"").trim();
  const fileSize=Number(formData.get("fileSize"));
  const customerId=String(formData.get("customerId")??"").trim();
  const salesDocumentId=String(formData.get("salesDocumentId")??"").trim();
  const purchaseOrderId=String(formData.get("purchaseOrderId")??"").trim();

  if(!storagePath||!fileName||fileName.length>180||!allowedTypes.has(contentType)||!Number.isFinite(fileSize)||fileSize<=0||fileSize>10*1024*1024){
    return {ok:false,message:"File details are invalid or exceed the 10 MB limit."};
  }
  if([customerId,salesDocumentId,purchaseOrderId].filter(Boolean).length>1){
    return {ok:false,message:"Link a document to only one business record."};
  }

  const context=await getCompanyContext();
  const expectedPrefix=`${context.active.companyId}/`;
  if(!storagePath.startsWith(expectedPrefix)||storagePath.includes("..")){
    return {ok:false,message:"The storage path does not belong to the active company."};
  }
  if(!["owner","admin","manager","sales","purchasing","operations","data_entry"].includes(context.active.role)){
    return {ok:false,message:"Your role does not allow document uploads."};
  }

  const {error}=await context.supabase.from("documents").insert({
    company_id:context.active.companyId,
    storage_bucket:"bokan-erp-documents",
    storage_path:storagePath,
    file_name:fileName,
    content_type:contentType,
    file_size_bytes:fileSize,
    related_customer_id:customerId||null,
    related_sales_document_id:salesDocumentId||null,
    related_purchase_order_id:purchaseOrderId||null,
    uploaded_by:context.user.id
  });
  if(error)return {ok:false,message:"The file uploaded, but its document record could not be saved. The file has been removed; please try again."};
  revalidatePath("/documents");
  return {ok:true,message:"Document uploaded and registered securely."};
}
