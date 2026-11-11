import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";
import { createDeliveryJob, updateDeliveryStatus } from "./actions";

export const dynamic = "force-dynamic";

export default async function LogisticsPage() {
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const [{data:deliveries},{data:documents},{data:customers}] = await Promise.all([
    context.supabase.from("delivery_jobs").select("id,delivery_reference,sales_document_id,customer_id,planned_for,dispatched_at,delivered_at,status,carrier_name,vehicle_reference,delivery_address,exception_notes").eq("company_id",companyId).order("created_at",{ascending:false}).limit(300),
    context.supabase.from("sales_documents").select("id,document_number,customer_id").eq("company_id",companyId).in("status",["approved","sent","accepted"]).order("created_at",{ascending:false}).limit(300),
    context.supabase.from("customers").select("id,legal_name,display_name").eq("company_id",companyId).order("display_name").limit(500)
  ]);
  const documentName = new Map((documents??[]).map(d=>[d.id,d.document_number]));
  const customerName = new Map((customers??[]).map(c=>[c.id,c.display_name||c.legal_name]));
  const canWrite = ["owner","admin","manager","sales","operations","data_entry"].includes(context.active.role);

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Delivery operations · {context.active.displayName}</div>
      <h1>Logistics & Delivery</h1>
      <p className="workspace-description">Plan deliveries from approved sales documents, coordinate carriers and vehicles, record dispatch and delivery confirmation, and track exceptions. This module does not post stock movements.</p>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Delivery register</h2><p>Delivery commitments and milestones for the active company.</p></div><span className="record-count">{deliveries?.length??0} deliveries</span></div>
        {deliveries?.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Delivery ref</th><th>Sales document</th><th>Customer</th><th>Planned</th><th>Carrier / vehicle</th><th>Status</th><th>Update</th></tr></thead><tbody>{deliveries.map(d=><tr key={d.id}><td><strong>{d.delivery_reference}</strong></td><td>{d.sales_document_id?documentName.get(d.sales_document_id)??"—":"—"}</td><td>{customerName.get(d.customer_id)??"—"}</td><td>{d.planned_for?new Date(d.planned_for).toLocaleString():"—"}</td><td>{d.carrier_name??"—"}<small>{d.vehicle_reference??""}</small></td><td><span className="stage-pill">{d.status}</span>{d.delivered_at?<small>Delivered {new Date(d.delivered_at).toLocaleString()}</small>:null}</td><td>{canWrite?<form action={updateDeliveryStatus} className="delivery-update-form"><input type="hidden" name="deliveryId" value={d.id}/><select name="status" defaultValue={d.status} aria-label={`Status for ${d.delivery_reference}`}><option value="planned">Planned</option><option value="scheduled">Scheduled</option><option value="dispatched">Dispatched</option><option value="delivered">Delivered</option><option value="delayed">Delayed</option><option value="cancelled">Cancelled</option></select><input name="exceptionNotes" defaultValue={d.exception_notes??""} placeholder="Exception note" maxLength={1000}/><button type="submit">Save</button></form>:"—"}</td></tr>)}</tbody></table></div>:<div className="workspace-empty"><div className="empty-mark">↗</div><h2>No deliveries planned</h2><p>Schedule a delivery from an approved sales document when the customer order is ready.</p></div>}
      </section>

      {canWrite?<section className="workspace-panel"><h2>Plan a delivery</h2><p className="panel-hint">Only approved, sent or accepted sales documents can be scheduled.</p>{documents?.length?<form action={createDeliveryJob} className="record-form"><div className="form-grid">
        <label>Sales document <span>*</span><select name="salesDocumentId" required defaultValue=""><option value="" disabled>Select sales document</option>{documents.map(d=><option key={d.id} value={d.id}>{d.document_number} · {customerName.get(d.customer_id)??"Customer"}</option>)}</select></label>
        <label>Planned delivery date/time<input name="plannedFor" type="datetime-local"/></label>
        <label>Carrier / transporter<input name="carrierName" maxLength={160}/></label>
        <label>Vehicle reference / plate<input name="vehicleReference" maxLength={80}/></label>
        <label className="form-wide">Delivery address<input name="deliveryAddress" maxLength={500}/></label>
      </div><div className="form-actions"><button type="submit">Create delivery plan</button></div></form>:<div className="workspace-empty"><h2>No approved sales documents</h2><p>Approve a quotation or proforma before scheduling delivery.</p></div>}</section>:null}
    </main>
  );
}
