import Link from "next/link";
import { notFound } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";
import { ActivityForm } from "../../crm-forms";
import { CustomerEditForm } from "../../customer-form";

type Props = { params: Promise<{ id: string }> };
export const dynamic = "force-dynamic";

const money = (value: number | null) => new Intl.NumberFormat("en-ET", {
  style: "currency", currency: "ETB", minimumFractionDigits: 2, maximumFractionDigits: 2
}).format(value ?? 0);

export default async function CustomerHistoryPage({ params }: Props) {
  const { id } = await params;
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const { data: customer, error } = await context.supabase.from("customers")
    .select("id,legal_name,display_name,contact_name,email,phone,address,tax_id,tax_number,notes,created_at")
    .eq("id", id).eq("company_id", companyId).maybeSingle();
  if (error || !customer) notFound();

  const [{ data: activities }, { data: leads }, { data: salesDocuments }, { data: tasks }] = await Promise.all([
    context.supabase.from("crm_activities")
      .select("id,activity_type,subject,details,occurred_at")
      .eq("company_id", companyId).eq("customer_id", customer.id)
      .order("occurred_at", { ascending: false }).limit(100),
    context.supabase.from("crm_leads")
      .select("id,title,stage,estimated_value,next_follow_up_at,created_at")
      .eq("company_id", companyId).eq("customer_id", customer.id)
      .order("created_at", { ascending: false }).limit(100),
    context.supabase.from("sales_documents")
      .select("id,document_number,document_type,status,issue_date,grand_total,vat_total")
      .eq("company_id", companyId).eq("customer_id", customer.id)
      .order("created_at", { ascending: false }).limit(100),
    context.supabase.from("tasks")
      .select("id,title,details,status,due_at")
      .eq("company_id", companyId).eq("customer_id", customer.id)
      .order("due_at", { ascending: true, nullsFirst: false }).limit(100)
  ]);

  const canCreate = ["owner", "admin", "manager", "sales", "data_entry"].includes(context.active.role);
  const customerOptions = [{ id: customer.id, display_name: customer.display_name, legal_name: customer.legal_name }];
  const leadOptions = (leads ?? []).map(lead => ({ id: lead.id, title: lead.title }));

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/crm">← Back to CRM</Link>
      <div className="eyebrow">Customer relationship history · {context.active.displayName}</div>
      <h1>{customer.display_name || customer.legal_name}</h1>
      <p className="workspace-description">Company-scoped customer profile, sales documents, opportunities, follow-ups and recorded interactions.</p>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Customer profile</h2><p>Created {new Date(customer.created_at).toLocaleDateString()}</p></div><span className="record-count">Customer record</span></div>
        <div className="profit-kpi-grid profit-kpi-grid-two">
          <article className="profit-kpi"><span>Legal name</span><strong>{customer.legal_name}</strong><small>{customer.tax_id || customer.tax_number ? `Tax ID: ${customer.tax_id || customer.tax_number}` : "Tax ID not recorded"}</small></article>
          <article className="profit-kpi"><span>Primary contact</span><strong>{customer.contact_name || "—"}</strong><small>{customer.phone || "No phone recorded"}</small></article>
        </div>
        <div className="role-boundary-list">
          <p><strong>Email</strong><span>{customer.email || "—"}</span></p>
          <p><strong>Phone</strong><span>{customer.phone || "—"}</span></p>
          <p><strong>Address</strong><span>{customer.address || "—"}</span></p>
          <p><strong>Notes</strong><span>{customer.notes || "—"}</span></p>
        </div>
      </section>

      {canCreate ? <section className="workspace-panel"><h2>Edit customer details</h2><p className="panel-hint">Changes apply only to this company’s customer record.</p><CustomerEditForm customer={customer} /></section> : null}

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Opportunities & pipeline</h2><p>Leads linked to this customer.</p></div><span className="record-count">{leads?.length ?? 0} leads</span></div>
        {leads?.length ? <div className="table-scroll"><table className="records-table"><thead><tr><th>Opportunity</th><th>Stage</th><th>Estimated value</th><th>Next follow-up</th></tr></thead><tbody>{leads.map(lead => <tr key={lead.id}><td><strong>{lead.title}</strong></td><td><span className="stage-pill">{lead.stage}</span></td><td>{lead.estimated_value == null ? "—" : money(Number(lead.estimated_value))}</td><td>{lead.next_follow_up_at ? new Date(lead.next_follow_up_at).toLocaleDateString() : "—"}</td></tr>)}</tbody></table></div> : <div className="workspace-empty"><h2>No linked opportunities</h2><p>Associate a lead with this customer when creating it in CRM.</p></div>}
      </section>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Sales documents</h2><p>Quotations, proformas and sales orders for this customer.</p></div><span className="record-count">{salesDocuments?.length ?? 0} documents</span></div>
        {salesDocuments?.length ? <div className="table-scroll"><table className="records-table"><thead><tr><th>Document</th><th>Date</th><th>Status</th><th>Net before VAT</th><th>Total</th></tr></thead><tbody>{salesDocuments.map(doc => <tr key={doc.id}><td><Link className="document-link" href={`/sales/${doc.id}`}>{doc.document_number}</Link><small>{doc.document_type.replace("_", " ")}</small></td><td>{new Date(doc.issue_date + "T00:00:00").toLocaleDateString()}</td><td><span className="stage-pill">{doc.status}</span></td><td>{money(Number(doc.grand_total) - Number(doc.vat_total))}</td><td><strong>{money(Number(doc.grand_total))}</strong></td></tr>)}</tbody></table></div> : <div className="workspace-empty"><h2>No sales documents</h2><p>Commercial documents created for this customer will appear here.</p></div>}
      </section>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Calls, visits & interaction history</h2><p>Chronological record of customer contact and follow-up.</p></div><span className="record-count">{activities?.length ?? 0} activities</span></div>
        {canCreate ? <ActivityForm customers={customerOptions} leads={leadOptions} defaultCustomerId={customer.id} /> : <p className="panel-hint">Your role is read-only for customer activity.</p>}
        {activities?.length ? <div className="activity-list">{activities.map(activity => <article className="activity-item" key={activity.id}><span className="activity-type">{activity.activity_type}</span><div><strong>{activity.subject}</strong><p>{activity.details || "No additional details"}</p></div><time>{new Date(activity.occurred_at).toLocaleString()}</time></article>)}</div> : <div className="workspace-empty"><h2>No recorded interactions</h2><p>Calls, visits, meetings and notes will appear here.</p></div>}
      </section>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Open commitments & reminders</h2><p>Tasks linked to this customer.</p></div><span className="record-count">{tasks?.length ?? 0} tasks</span></div>
        {tasks?.length ? <div className="task-list">{tasks.map(task => <article className="task-item" key={task.id}><div className="task-copy"><strong>{task.title}</strong><p>{task.details || "No additional details"}</p><time>{task.due_at ? `Due ${new Date(task.due_at).toLocaleDateString()}` : "No due date"}</time></div><span className="stage-pill">{task.status.replace("_", " ")}</span></article>)}</div> : <div className="workspace-empty"><h2>No linked tasks</h2><p>Customer reminders and follow-up tasks will appear here.</p></div>}
      </section>
    </main>
  );
}
