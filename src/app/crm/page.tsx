import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";
import { CustomerForm } from "./customer-form";
import { ActivityForm, LeadForm } from "./crm-forms";
import { updateLeadStage } from "./actions";

export const dynamic = "force-dynamic";

export default async function CRMPage() {
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const [{ data: customers, error: customerError }, { data: leads, error: leadError }, { data: activities }] = await Promise.all([
    context.supabase.from("customers")
      .select("id, legal_name, display_name, phone, email, created_at")
      .eq("company_id", companyId).order("created_at", { ascending: false }).limit(100),
    context.supabase.from("crm_leads")
      .select("id, title, stage, contact_name, customer_id, next_follow_up_at, estimated_value")
      .eq("company_id", companyId).order("created_at", { ascending: false }).limit(100),
    context.supabase.from("crm_activities")
      .select("id, activity_type, subject, details, occurred_at")
      .eq("company_id", companyId).order("occurred_at", { ascending: false }).limit(30)
  ]);

  const canCreate = ["owner", "admin", "manager", "sales", "data_entry"].includes(context.active.role);
  const customerOptions = customers ?? [];
  const leadOptions = leads ?? [];
  const customerName = new Map(customerOptions.map(customer => [customer.id, customer.display_name || customer.legal_name]));

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Customer relationships · {context.active.displayName}</div>
      <h1>CRM & Customers</h1>
      <p className="workspace-description">Manage the customer directory, new opportunities and the sales team calls, visits and follow-up history.</p>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Customer directory</h2><p>Only records belonging to the active company are shown.</p></div><span className="record-count">{customerOptions.length} records</span></div>
        {customerError ? <div className="workspace-notice"><strong>Customer records are unavailable.</strong>The V7 schema may not yet be installed in this isolated environment.</div> : customerOptions.length ? (
          <div className="table-scroll"><table className="records-table"><thead><tr><th>Customer</th><th>Phone</th><th>Email</th><th>Created</th></tr></thead><tbody>{customerOptions.map((customer) => <tr key={customer.id}><td><Link className="document-link" href={`/crm/customers/${customer.id}`}>{customer.display_name || customer.legal_name}</Link><small>{customer.legal_name}</small></td><td>{customer.phone || "—"}</td><td>{customer.email || "—"}</td><td>{new Date(customer.created_at).toLocaleDateString()}</td></tr>)}</tbody></table></div>
        ) : <div className="workspace-empty"><div className="empty-mark">＋</div><h2>No customers yet</h2><p>This company directory is empty. Add your newly prepared customer records when ready.</p></div>}
      </section>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Lead pipeline</h2><p>Move opportunities through qualification, proposal, negotiation and close.</p></div><span className="record-count">{leadOptions.length} leads</span></div>
        {leadError ? <div className="workspace-notice"><strong>Lead records are unavailable.</strong>The V7 CRM schema may not yet be installed.</div> : leadOptions.length ? (
          <div className="table-scroll"><table className="records-table"><thead><tr><th>Opportunity</th><th>Customer</th><th>Contact</th><th>Stage</th><th>Estimated value</th><th>Next follow-up</th></tr></thead><tbody>{leadOptions.map((lead) => <tr key={lead.id}><td><strong>{lead.title}</strong></td><td>{lead.customer_id ? <Link className="document-link" href={`/crm/customers/${lead.customer_id}`}>{customerName.get(lead.customer_id) ?? "Customer"}</Link> : "Prospect"}</td><td>{lead.contact_name || "—"}</td><td><form action={updateLeadStage} className="inline-stage-form"><input type="hidden" name="leadId" value={lead.id} /><select name="stage" defaultValue={lead.stage} aria-label={`Stage for ${lead.title}`} disabled={!canCreate}><option value="new">New</option><option value="qualified">Qualified</option><option value="proposal">Proposal</option><option value="negotiation">Negotiation</option><option value="won">Won</option><option value="lost">Lost</option></select>{canCreate ? <button type="submit">Update</button> : null}</form></td><td>{lead.estimated_value == null ? "—" : new Intl.NumberFormat("en-ET", { style: "currency", currency: "ETB", maximumFractionDigits: 2 }).format(lead.estimated_value)}</td><td>{lead.next_follow_up_at ? new Date(lead.next_follow_up_at).toLocaleDateString() : "—"}</td></tr>)}</tbody></table></div>
        ) : <div className="workspace-empty"><div className="empty-mark">＋</div><h2>No leads yet</h2><p>New sales opportunities will appear here after the team records them.</p></div>}
      </section>

      {canCreate ? <div className="crm-entry-grid">
        <section className="workspace-panel"><h2>Add a customer</h2><p className="panel-hint">Create a new V7 customer record. No legacy customer data is preloaded.</p><CustomerForm /></section>
        <section className="workspace-panel"><h2>Capture a lead</h2><p className="panel-hint">Record a prospect, estimated value and the next follow-up date.</p><LeadForm customers={customerOptions} /></section>
      </div> : null}

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Calls, visits & customer history</h2><p>Record contact attempts and follow-up activity against a customer or lead.</p></div></div>
        {canCreate ? <ActivityForm customers={customerOptions} leads={leadOptions} /> : <p className="panel-hint">Your current role is read-only for CRM activities.</p>}
        <div className="activity-list">{activities?.length ? activities.map((activity) => <article className="activity-item" key={activity.id}><span className="activity-type">{activity.activity_type}</span><div><strong>{activity.subject}</strong><p>{activity.details || "No additional details"}</p></div><time>{new Date(activity.occurred_at).toLocaleString()}</time></article>) : <div className="workspace-empty"><h2>No activity history yet</h2><p>Calls, visits, meetings and reminders will appear here when recorded.</p></div>}</div>
      </section>
    </main>
  );
}
