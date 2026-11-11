"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { registerDocument } from "./actions";

const bucket = "bokan-erp-documents";
const allowedTypes = [
  "application/pdf",
  "image/jpeg",
  "image/png",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
];

type Props = {
  companyId: string;
  customers: Array<{id:string;legal_name:string;display_name:string}>;
  salesDocuments: Array<{id:string;document_number:string}>;
  purchaseOrders: Array<{id:string;order_number:string}>;
};

export function DocumentUploader({companyId,customers,salesDocuments,purchaseOrders}:Props) {
  const router=useRouter();
  const [busy,setBusy]=useState(false);
  const [message,setMessage]=useState("");
  const [success,setSuccess]=useState(false);

  async function submit(event:FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);setMessage("");setSuccess(false);
    const form=event.currentTarget;
    const data=new FormData(form);
    const file=data.get("file");
    if(!(file instanceof File)||file.size===0){setMessage("Choose a file to upload.");setBusy(false);return;}
    if(file.size>10*1024*1024){setMessage("The file exceeds the 10 MB limit.");setBusy(false);return;}
    if(!allowedTypes.includes(file.type)){setMessage("Allowed formats: PDF, JPG, PNG, DOCX and XLSX.");setBusy(false);return;}

    const customerId=String(data.get("customerId")??"");
    const salesDocumentId=String(data.get("salesDocumentId")??"");
    const purchaseOrderId=String(data.get("purchaseOrderId")??"");
    if([customerId,salesDocumentId,purchaseOrderId].filter(Boolean).length>1){
      setMessage("Link the file to only one business record.");setBusy(false);return;
    }

    const safeName=file.name.normalize("NFKD").replace(/[^a-zA-Z0-9._-]+/g,"_").slice(-140)||"document";
    const storagePath=`${companyId}/${crypto.randomUUID()}-${safeName}`;
    try{
      const supabase=createSupabaseBrowserClient();
      const {error:uploadError}=await supabase.storage.from(bucket).upload(storagePath,file,{
        cacheControl:"3600",upsert:false,contentType:file.type
      });
      if(uploadError)throw uploadError;

      const metadata=new FormData();
      metadata.set("storagePath",storagePath);
      metadata.set("fileName",file.name.slice(0,180));
      metadata.set("contentType",file.type);
      metadata.set("fileSize",String(file.size));
      metadata.set("customerId",customerId);
      metadata.set("salesDocumentId",salesDocumentId);
      metadata.set("purchaseOrderId",purchaseOrderId);
      const result=await registerDocument(metadata);
      if(!result.ok){
        await supabase.storage.from(bucket).remove([storagePath]);
        setMessage(result.message);setBusy(false);return;
      }
      setMessage(result.message);setSuccess(true);form.reset();router.refresh();
    }catch(error){
      setMessage(error instanceof Error?error.message:"Upload could not be completed. Check your access and try again.");
    }finally{setBusy(false);}
  }

  return (
    <form className="record-form" onSubmit={submit}>
      <div className="form-grid">
        <label>Choose file <span>*</span><input name="file" type="file" required accept=".pdf,.jpg,.jpeg,.png,.docx,.xlsx,application/pdf,image/jpeg,image/png" /></label>
        <label>Link to customer (optional)<select name="customerId" defaultValue=""><option value="">No customer link</option>{customers.map(c=><option key={c.id} value={c.id}>{c.display_name||c.legal_name}</option>)}</select></label>
        <label>Link to sales document (optional)<select name="salesDocumentId" defaultValue=""><option value="">No sales document link</option>{salesDocuments.map(d=><option key={d.id} value={d.id}>{d.document_number}</option>)}</select></label>
        <label>Link to purchase order (optional)<select name="purchaseOrderId" defaultValue=""><option value="">No purchase order link</option>{purchaseOrders.map(p=><option key={p.id} value={p.id}>{p.order_number}</option>)}</select></label>
      </div>
      <p className="panel-hint">Private company storage · maximum 10 MB · PDF, JPG, PNG, DOCX or XLSX. Link each file to no more than one record.</p>
      {message?<p className={success?"form-success":"form-error"} role="status">{message}</p>:null}
      <div className="form-actions"><button type="submit" disabled={busy}>{busy?"Uploading securely…":"Upload document"}</button></div>
    </form>
  );
}
