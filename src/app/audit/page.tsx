import Link from "next/link";
import { redirect } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";

export const dynamic="force-dynamic";

type AuditEvent={id:number;actor_user_id:string|null;action:string;entity_table:string;entity_id:string|null;occurred_at:string;request_id:string|null;metadata:Record<string,unknown>|null};
type Member={user_id:string;email:string|null;role:string;is_active:boolean;created_at:string};

export default async function AuditPage() {
  const context=await getCompanyContext();
  if(!["owner","admin","manager"].includes(context.active.role))redirect("/");
  const [{data:events,error},{data:members}]=await Promise.all([
    context.supabase.from("audit_events").select("id,actor_user_id,action,entity_table,entity_id,occurred_at,request_id,metadata").eq("company_id",context.active.companyId).order("occurred_at",{ascending:false}).limit(200),
    context.supabase.rpc("list_company_members",{target_company_id:context.active.companyId})
  ]);
  const memberMap=new Map(((members??[]) as Member[]).map(member=>[member.user_id,member.email||member.user_id]));
  const rows=(events??[]) as AuditEvent[];

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Governance · {context.active.displayName}</div>
      <h1>Audit log</h1>
      <p className="workspace-description">Append-only record of business changes in the active company. Events are company-scoped and cannot be edited or deleted through the application.</p>
      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Recent activity</h2><p>Latest 200 events · newest first</p></div><span className="record-count">{rows.length} events</span></div>
        {error?<div className="workspace-notice"><strong>Audit history unavailable.</strong>Check your company membership and audit permissions.</div>:rows.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Time</th><th>Actor</th><th>Action</th><th>Record</th><th>Details</th></tr></thead><tbody>{rows.map(event=><tr key={event.id}><td>{new Date(event.occurred_at).toLocaleString()}</td><td>{event.actor_user_id?memberMap.get(event.actor_user_id)??event.actor_user_id:"System"}</td><td><span className="stage-pill">{event.action}</span></td><td><strong>{event.entity_table}</strong><small>{event.entity_id??"—"}</small></td><td><details className="audit-details"><summary>View metadata</summary><pre>{JSON.stringify(event.metadata??{},null,2)}</pre>{event.request_id?<small>Request: {event.request_id}</small>:null}</details></td></tr>)}</tbody></table></div>:<div className="workspace-empty"><div className="empty-mark">≡</div><h2>No audit events yet</h2><p>New business changes will be recorded here as users begin using V7.</p></div>}
      </section>
    </main>
  );
}
