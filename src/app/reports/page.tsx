import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";

export const dynamic = "force-dynamic";
const money = (value:number) => new Intl.NumberFormat("en-ET",{style:"currency",currency:"ETB",minimumFractionDigits:2,maximumFractionDigits:2}).format(value);

export default async function ReportsPage() {
  const context=await getCompanyContext();
  const companyId=context.active.companyId;
  const [{data:leads},{data:activities},{data:sales},{data:purchaseOrders},{data:tasks},{data:customers}] = await Promise.all([
    context.supabase.from("crm_leads").select("id,title,stage,estimated_value,assigned_to,created_at").eq("company_id",companyId).order("created_at",{ascending:false}).limit(1000),
    context.supabase.from("crm_activities").select("id,activity_type,assigned_to,occurred_at").eq("company_id",companyId).order("occurred_at",{ascending:false}).limit(3000),
    context.supabase.from("sales_documents").select("id,document_number,status,document_type,grand_total,vat_total,created_by,issue_date").eq("company_id",companyId).order("created_at",{ascending:false}).limit(1000),
    context.supabase.from("purchase_orders").select("id,status,grand_total").eq("company_id",companyId).limit(1000),
    context.supabase.from("tasks").select("id,status,assigned_to,due_at").eq("company_id",companyId).limit(2000),
    context.supabase.from("customers").select("id").eq("company_id",companyId).limit(5000)
  ]);

  const stageCounts=new Map<string,number>();
  for(const lead of leads??[])stageCounts.set(lead.stage,(stageCounts.get(lead.stage)??0)+1);
  const activityCounts=new Map<string,number>();
  for(const activity of activities??[])activityCounts.set(activity.activity_type,(activityCounts.get(activity.activity_type)??0)+1);
  const activityByMember=new Map<string,number>();
  for(const activity of activities??[])if(activity.assigned_to)activityByMember.set(activity.assigned_to,(activityByMember.get(activity.assigned_to)??0)+1);
  const salesByStatus=new Map<string,{count:number;value:number}>();
  for(const doc of sales??[]){const row=salesByStatus.get(doc.status)??{count:0,value:0};row.count++;row.value+=Number(doc.grand_total)-Number(doc.vat_total);salesByStatus.set(doc.status,row);}
  const approvedSales=(sales??[]).filter(doc=>["approved","sent","accepted"].includes(doc.status));
  const revenueExVat=approvedSales.reduce((sum,doc)=>sum+Number(doc.grand_total)-Number(doc.vat_total),0);
  const openTasks=(tasks??[]).filter(task=>["open","in_progress"].includes(task.status)).length;
  const overdueTasks=(tasks??[]).filter(task=>["open","in_progress"].includes(task.status)&&task.due_at&&new Date(task.due_at)<new Date()).length;
  const closedLeads=(leads??[]).filter(lead=>["won","lost"].includes(lead.stage)).length;
  const activeLeads=(leads??[]).filter(lead=>!["won","lost"].includes(lead.stage)).length;
  const pipelineValue=(leads??[]).filter(lead=>!["won","lost"].includes(lead.stage)).reduce((sum,lead)=>sum+Number(lead.estimated_value??0),0);
  const memberActivity=[...activityByMember.entries()].sort((a,b)=>b[1]-a[1]).slice(0,10);
  const canSeeMemberNames=["owner","admin","manager"].includes(context.active.role);
  const {data:members}=canSeeMemberNames
    ? await context.supabase.rpc("list_company_members",{target_company_id:companyId})
    : {data:[]};
  const memberNameMap=new Map(((members??[]) as Array<{user_id:string;email:string|null}>).map(member=>[member.user_id,member.email||member.user_id]));

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Management information · {context.active.displayName}</div>
      <h1>Reports</h1>
      <p className="workspace-description">Live management summaries from the active company’s V7 records. Commercial revenue excludes VAT; these reports are not accounting statements and do not include receipts or payments.</p>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Commercial overview</h2><p>Current records from the active company.</p></div><span className="record-count">Live data</span></div>
        <div className="profit-kpi-grid">
          <article className="profit-kpi"><span>Customers</span><strong>{customers?.length??0}</strong><small>Company customer directory</small></article>
          <article className="profit-kpi"><span>Active opportunities</span><strong>{activeLeads}</strong><small>{closedLeads} won / lost leads</small></article>
          <article className="profit-kpi"><span>Open tasks</span><strong>{openTasks}</strong><small>{overdueTasks} overdue</small></article>
          <article className="profit-kpi"><span>Approved sales · net of VAT</span><strong>{money(revenueExVat)}</strong><small>{approvedSales.length} approved / sent / accepted documents</small></article>
        </div>
      </section>

      <section className="workspace-panel">
        <h2>CRM pipeline health</h2><p className="panel-hint">Opportunity values are estimates entered by the sales team, not recognized revenue.</p>
        <div className="profit-kpi-grid profit-kpi-grid-two">
          <article className="profit-kpi"><span>Open pipeline estimate</span><strong>{money(pipelineValue)}</strong><small>{activeLeads} open opportunities</small></article>
          <article className="profit-kpi"><span>CRM interactions recorded</span><strong>{activities?.length??0}</strong><small>Calls, visits, meetings, emails and notes</small></article>
        </div>
        {leads?.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Pipeline stage</th><th>Lead count</th></tr></thead><tbody>{["new","qualified","proposal","negotiation","won","lost"].map(stage=><tr key={stage}><td>{stage}</td><td>{stageCounts.get(stage)??0}</td></tr>)}</tbody></table></div>:<div className="workspace-empty"><h2>No CRM pipeline records</h2><p>Lead stage summaries will appear when your sales team records opportunities.</p></div>}
      </section>

      <section className="workspace-panel">
        <h2>Sales document summary</h2>
        {sales?.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Document status</th><th>Count</th><th>Document value excluding VAT</th></tr></thead><tbody>{["draft","submitted","approved","sent","accepted","rejected","expired","cancelled"].map(status=>{const row=salesByStatus.get(status)??{count:0,value:0};return <tr key={status}><td>{status}</td><td>{row.count}</td><td>{money(row.value)}</td></tr>})}</tbody></table></div>:<div className="workspace-empty"><h2>No sales documents</h2><p>Sales register summaries will appear when documents are created.</p></div>}
      </section>

      <section className="workspace-panel">
        <h2>Sales activity mix</h2>
        {activities?.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Activity type</th><th>Recorded</th></tr></thead><tbody>{["call","visit","meeting","email","note","reminder"].map(type=><tr key={type}><td>{type}</td><td>{activityCounts.get(type)??0}</td></tr>)}</tbody></table></div>:<div className="workspace-empty"><h2>No recorded activities</h2><p>Calls and visits recorded in CRM will appear here.</p></div>}
        {memberActivity.length?<><h3 className="subsection-title">Activity by assigned team account</h3><div className="table-scroll"><table className="records-table"><thead><tr><th>Assigned account</th><th>Activities</th></tr></thead><tbody>{memberActivity.map(([id,count])=><tr key={id}><td>{canSeeMemberNames?memberNameMap.get(id)??id.slice(0,8)+"…":id===context.user.id?"You":"Team member"}</td><td>{count}</td></tr>)}</tbody></table></div><p className="panel-hint">Management roles see company member emails here; other roles see their own activity as “You” and other activity as “Team member”.</p></>:null}
      </section>

      <section className="workspace-panel">
        <h2>Purchasing & task status</h2>
        <div className="profit-kpi-grid profit-kpi-grid-two">
          <article className="profit-kpi"><span>Purchase orders</span><strong>{purchaseOrders?.length??0}</strong><small>{money((purchaseOrders??[]).reduce((sum,order)=>sum+Number(order.grand_total),0))} total commitment value</small></article>
          <article className="profit-kpi"><span>Completed tasks</span><strong>{(tasks??[]).filter(task=>task.status==="completed").length}</strong><small>{tasks?.length??0} total tasks and reminders</small></article>
        </div>
      </section>
      <p className="profit-footnote">For landed gross profit and profit after direct costs, use the <Link href="/profitability">Profitability workspace</Link>. Only owners, admins and managers see company member email labels; other roles do not see colleagues’ account details.</p>
    </main>
  );
}
