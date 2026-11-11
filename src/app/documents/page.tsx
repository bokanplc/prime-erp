import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";
import { DocumentUploader } from "./document-uploader";

export const dynamic = "force-dynamic";
const sizeLabel=(bytes:number|null)=>bytes===null?"—":bytes<1024*1024?`${(bytes/1024).toFixed(0)} KB`:`${(bytes/(1024*1024)).toFixed(1)} MB`;

export default async function DocumentsPage() {
  const context=await getCompanyContext();
  const companyId=context.active.companyId;
  const [{data:documents},{data:customers},{data:salesDocuments},{data:purchaseOrders}] = await Promise.all([
    context.supabase.from("documents").select("id,storage_bucket,storage_path,file_name,content_type,file_size_bytes,related_customer_id,related_sales_document_id,related_purchase_order_id,created_at").eq("company_id",companyId).order("created_at",{ascending:false}).limit(500),
    context.supabase.from("customers").select("id,legal_name,display_name").eq("company_id",companyId).order("display_name").limit(500),
    context.supabase.from("sales_documents").select("id,document_number").eq("company_id",companyId).order("created_at",{ascending:false}).limit(500),
    context.supabase.from("purchase_orders").select("id,order_number").eq("company_id",companyId).order("created_at",{ascending:false}).limit(500)
  ]);
  const customerName=new Map((customers??[]).map(c=>[c.id,c.display_name||c.legal_name]));
  const salesName=new Map((salesDocuments??[]).map(d=>[d.id,d.document_number]));
  const purchaseName=new Map((purchaseOrders??[]).map(p=>[p.id,p.order_number]));
  const signedDocuments=await Promise.all((documents??[]).map(async doc=>{
    const {data,error}=await context.supabase.storage.from(doc.storage_bucket).createSignedUrl(doc.storage_path,300);
    return {...doc,signedUrl:error?null:data?.signedUrl??null};
  }));
  const canUpload=["owner","admin","manager","sales","purchasing","operations","data_entry"].includes(context.active.role);

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Controlled files · {context.active.displayName}</div>
      <h1>Documents</h1>
      <p className="workspace-description">Upload and retrieve company documents through private tenant-scoped storage. Files are never placed in a public bucket; signed download links expire after five minutes.</p>

      {canUpload?<section className="workspace-panel"><h2>Upload a document</h2><p className="panel-hint">Store a customer file, quotation attachment, supplier document or other approved company record.</p><DocumentUploader companyId={companyId} customers={customers??[]} salesDocuments={salesDocuments??[]} purchaseOrders={purchaseOrders??[]}/></section>:null}

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Company document register</h2><p>Only files and metadata belonging to the active company are shown.</p></div><span className="record-count">{signedDocuments.length} documents</span></div>
        {signedDocuments.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>File</th><th>Type</th><th>Size</th><th>Related record</th><th>Uploaded</th><th>Access</th></tr></thead><tbody>{signedDocuments.map(doc=>{
          const related=doc.related_customer_id?customerName.get(doc.related_customer_id):doc.related_sales_document_id?salesName.get(doc.related_sales_document_id):doc.related_purchase_order_id?purchaseName.get(doc.related_purchase_order_id):null;
          return <tr key={doc.id}><td><strong>{doc.file_name}</strong></td><td>{doc.content_type??"—"}</td><td>{sizeLabel(doc.file_size_bytes)}</td><td>{related??"General document"}</td><td>{new Date(doc.created_at).toLocaleString()}</td><td>{doc.signedUrl?<a className="document-download" href={doc.signedUrl} target="_blank" rel="noreferrer">Download ↗</a>:"Access unavailable"}</td></tr>;
        })}</tbody></table></div>:<div className="workspace-empty"><div className="empty-mark">▧</div><h2>No documents stored</h2><p>Files uploaded here are stored privately and scoped to the active company. No legacy files have been imported.</p></div>}
      </section>
      <p className="profit-footnote">Supported formats: PDF, JPG, PNG, DOCX and XLSX. Maximum size: 10 MB per file. Access is enforced by Supabase Storage policies and company membership.</p>
    </main>
  );
}
