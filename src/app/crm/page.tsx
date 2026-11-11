import { getCompanyContext } from "@/lib/auth/company-context";
import { CustomerForm } from "./customer-form";

export default async function CRMPage() {
  const context = await getCompanyContext();
  const { data: customers, error } = await context.supabase
    .from("customers")
    .select("id, legal_name, display_name, phone, email, created_at")
    .eq("company_id", context.active.companyId)
    .order("created_at", { ascending: false })
    .limit(100);

  const canCreate = ["owner", "admin", "manager", "sales", "data_entry"].includes(context.active.role);

  return (
    <main className="workspace-page">
      <a className="back-link" href="/">← BOKAN ERP overview</a>
      <div className="eyebrow">Customer relationships · {context.active.displayName}</div>
      <h1>CRM & Customers</h1>
      <p className="workspace-description">Manage customer records and build the relationship history used by the sales team.</p>
      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Customer directory</h2><p>Only records belonging to the active company are shown.</p></div><span className="record-count">{customers?.length ?? 0} records</span></div>
        {error ? <div className="workspace-notice"><strong>Customer records are unavailable.</strong>The V7 schema may not yet be installed in this isolated environment.</div> : customers?.length ? (
          <div className="table-scroll"><table className="records-table"><thead><tr><th>Customer</th><th>Phone</th><th>Email</th><th>Created</th></tr></thead><tbody>{customers.map((customer) => <tr key={customer.id}><td><strong>{customer.display_name || customer.legal_name}</strong><small>{customer.legal_name}</small></td><td>{customer.phone || "—"}</td><td>{customer.email || "—"}</td><td>{new Date(customer.created_at).toLocaleDateString()}</td></tr>)}</tbody></table></div>
        ) : <div className="workspace-empty"><div className="empty-mark">＋</div><h2>No customers yet</h2><p>This company directory is empty. Add your newly prepared customer records when ready.</p></div>}
      </section>
      {canCreate ? <section className="workspace-panel"><h2>Add a customer</h2><p className="panel-hint">Create a new V7 customer record. No legacy customer data is preloaded.</p><CustomerForm /></section> : null}
      <section className="workspace-panel"><h2>CRM capabilities being built</h2><ul><li>Lead pipeline and stage history</li><li>Calls, visits and customer meetings</li><li>Follow-up reminders and tasks</li><li>Customer interaction timeline</li><li>Salesperson activity and performance</li></ul></section>
    </main>
  );
}
