import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";
import { addSalesDirectCost, approveSalesDocument, createSalesDocument } from "./actions";

export const dynamic = "force-dynamic";

const money = (value: number | null) => new Intl.NumberFormat("en-ET", {
  style: "currency", currency: "ETB", minimumFractionDigits: 2, maximumFractionDigits: 2
}).format(value ?? 0);

export default async function SalesPage() {
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const [{ data: customers }, { data: documents }, { data: lines }, { data: costs }] = await Promise.all([
    context.supabase.from("customers").select("id, legal_name, display_name").eq("company_id", companyId).order("display_name").limit(500),
    context.supabase.from("sales_documents").select("id, document_number, document_type, status, issue_date, valid_until, subtotal, discount_total, vat_treatment, vat_total, grand_total, customer_id, created_at").eq("company_id", companyId).order("created_at", { ascending: false }).limit(100),
    context.supabase.from("sales_document_lines").select("id, sales_document_id, description, quantity, unit_of_measure, unit_price, discount_amount, line_net").eq("company_id", companyId).limit(1000),
    context.supabase.from("direct_costs").select("id, sales_document_id, category, description, amount, incurred_on").eq("company_id", companyId).not("sales_document_id", "is", null).order("incurred_on", { ascending: false }).limit(500)
  ]);

  const customerName = new Map((customers ?? []).map(c => [c.id, c.display_name || c.legal_name]));
  const linesByDocument = new Map<string, NonNullable<typeof lines>[number][]>();
  for (const line of lines ?? []) {
    const group = linesByDocument.get(line.sales_document_id) ?? [];
    group.push(line);
    linesByDocument.set(line.sales_document_id, group);
  }
  const costsByDocument = new Map<string, NonNullable<typeof costs>[number][]>();
  for (const cost of costs ?? []) {
    if (!cost.sales_document_id) continue;
    const group = costsByDocument.get(cost.sales_document_id) ?? [];
    group.push(cost);
    costsByDocument.set(cost.sales_document_id, group);
  }

  const canCreate = ["owner", "admin", "manager", "sales", "data_entry"].includes(context.active.role);
  const canApprove = ["owner", "admin", "manager"].includes(context.active.role);

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Commercial transactions · {context.active.displayName}</div>
      <h1>Sales & Proformas</h1>
      <p className="workspace-description">Prepare quotations and proformas with customer-specific commercial terms, line discounts and Ethiopia’s standard 15% VAT calculation. This is not a payment or accounting module.</p>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Sales document register</h2><p>Submitted commercial documents for the active company.</p></div><span className="record-count">{documents?.length ?? 0} documents</span></div>
        {documents?.length ? <div className="table-scroll"><table className="records-table"><thead><tr><th>Document</th><th>Lines</th><th>Customer</th><th>Date</th><th>Net before VAT</th><th>VAT</th><th>Total</th><th>Status</th><th>Action</th></tr></thead><tbody>
          {documents.map(doc => <tr key={doc.id}><td><strong>{doc.document_number}</strong><small>{doc.document_type.replace("_", " ")}</small></td><td>{linesByDocument.get(doc.id)?.length ?? 0}</td><td>{customerName.get(doc.customer_id) ?? "—"}</td><td>{new Date(doc.issue_date + "T00:00:00").toLocaleDateString()}</td><td>{money((doc.grand_total ?? 0) - (doc.vat_total ?? 0))}</td><td>{money(doc.vat_total)}</td><td><strong>{money(doc.grand_total)}</strong></td><td><span className="stage-pill">{doc.status}</span></td><td>{canApprove && doc.status === "submitted" ? <form action={approveSalesDocument} className="inline-stage-form"><input type="hidden" name="documentId" value={doc.id} /><button type="submit">Approve</button></form> : "—"}</td></tr>)}
        </tbody></table></div> : <div className="workspace-empty"><div className="empty-mark">＋</div><h2>No sales documents</h2><p>Create your first quotation or proforma below. Nothing has been imported from the previous system.</p></div>}
      </section>

      {canCreate ? <section className="workspace-panel">
        <h2>Create quotation / proforma</h2>
        <p className="panel-hint">Enter up to four lines. Amounts are in ETB. The document is submitted for manager approval when saved.</p>
        {(customers ?? []).length ? <form action={createSalesDocument} className="record-form">
          <div className="form-grid">
            <label>Customer <span>*</span><select name="customerId" required defaultValue=""><option value="" disabled>Select customer</option>{(customers ?? []).map(c => <option key={c.id} value={c.id}>{c.display_name || c.legal_name}</option>)}</select></label>
            <label>Document type <span>*</span><select name="documentType" defaultValue="proforma"><option value="quotation">Quotation</option><option value="proforma">Proforma invoice</option><option value="sales_order">Sales order</option></select></label>
            <label>Issue date<input type="date" name="issueDate" /></label>
            <label>Valid until<input type="date" name="validUntil" /></label>
            <label>VAT treatment <span>*</span><select name="vatTreatment" defaultValue="exclusive"><option value="exclusive">15% VAT added (exclusive)</option><option value="inclusive">Price includes 15% VAT (inclusive)</option><option value="none">No VAT</option></select></label>
          </div>
          <div className="sales-lines">
            <div className="sales-lines-head"><strong>Document lines</strong><span>Description · Quantity · Unit price · Discount</span></div>
            {Array.from({length:4},(_,i)=><div className="sales-line" key={i}>
              <label>Description<input name="description" maxLength={240} placeholder={i===0?"Product / service description":"Optional line"} required={i===0} /></label>
              <label>Quantity<input name="quantity" type="number" min="0.001" step="0.001" defaultValue={i===0?"1":""} /></label>
              <label>Unit<input name="unitOfMeasure" maxLength={30} defaultValue="pcs" /></label>
              <label>Unit price (ETB)<input name="unitPrice" type="number" min="0" step="0.01" defaultValue={i===0?"0":""} /></label>
              <label>Discount (ETB)<input name="discountAmount" type="number" min="0" step="0.01" defaultValue="0" /></label>
            </div>)}
          </div>
          <label className="sales-terms">Terms and conditions<textarea name="terms" rows={3} maxLength={3000} /></label>
          <div className="form-actions"><button type="submit">Save and submit for approval</button></div>
        </form> : <div className="workspace-notice"><strong>Customer list is empty.</strong>Add the newly prepared customer records in CRM before creating sales documents.</div>}
      </section> : null}

      <section className="workspace-panel">
        <h2>Direct sales costs</h2>
        <p className="panel-hint">Record transaction-related transportation, loading or miscellaneous costs. These are not customer receipts or supplier payments.</p>
        {canCreate && documents?.length ? <form action={addSalesDirectCost} className="record-form">
          <div className="form-grid">
            <label>Sales document <span>*</span><select name="salesDocumentId" required defaultValue=""><option value="" disabled>Select a document</option>{(documents ?? []).map(d=><option key={d.id} value={d.id}>{d.document_number} · {customerName.get(d.customer_id) ?? "Customer"}</option>)}</select></label>
            <label>Cost category <span>*</span><select name="category" defaultValue="transportation"><option value="transportation">Transportation</option><option value="loading">Loading</option><option value="miscellaneous">Miscellaneous</option></select></label>
            <label>Description <span>*</span><input name="description" required maxLength={240} /></label>
            <label>Amount (ETB) <span>*</span><input name="amount" type="number" min="0.01" step="0.01" required /></label>
            <label>VAT treatment<select name="vatTreatment" defaultValue="none"><option value="none">No VAT / not specified</option><option value="exclusive">VAT exclusive</option><option value="inclusive">VAT inclusive</option></select></label>
            <label>Incurred on<input name="incurredOn" type="date" /></label>
            <label className="checkbox-label"><input type="checkbox" name="recoverableVat" /> Recoverable input VAT (only if documented)</label>
          </div>
          <div className="form-actions"><button type="submit">Save direct cost</button></div>
        </form> : <div className="workspace-empty"><h2>No eligible sales documents</h2><p>Create a sales document first. Direct costs are attached to a specific commercial transaction.</p></div>}
        {costs?.length ? <div className="table-scroll"><table className="records-table"><thead><tr><th>Date</th><th>Document</th><th>Category</th><th>Description</th><th>Amount</th></tr></thead><tbody>{costs.map(cost=><tr key={cost.id}><td>{new Date(cost.incurred_on + "T00:00:00").toLocaleDateString()}</td><td>{(documents ?? []).find(d=>d.id===cost.sales_document_id)?.document_number ?? "—"}</td><td>{cost.category}</td><td>{cost.description}</td><td>{money(cost.amount)}</td></tr>)}</tbody></table></div> : null}
      </section>
    </main>
  );
}
