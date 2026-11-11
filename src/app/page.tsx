import { SignOutButton } from "@/components/sign-out-button";
import { getCompanyContext } from "@/lib/auth/company-context";
import { CompanySwitcher } from "@/components/company-switcher";

export const dynamic = "force-dynamic";


const modules = [
  { icon: "◎", title: "CRM & Customers", href: "/crm", desc: "Customer records, leads, pipeline, calls, visits, reminders and relationship history.", tag: "Core workspace" },
  { icon: "▤", title: "Sales & Proformas", href: "/sales", desc: "Commercial offers, sales documents, pricing, VAT and approval stages.", tag: "Core workspace" },
  { icon: "⇄", title: "Purchasing", href: "/purchasing", desc: "Supplier directory, purchase requests, orders and purchase price records.", tag: "Core workspace" },
  { icon: "↗", title: "Profitability", href: "/profitability", desc: "Landed gross profit and profit after direct transaction costs.", tag: "Commercial insight" },
  { icon: "⌁", title: "Logistics & Delivery", href: "/logistics", desc: "Delivery orders, dispatch milestones, transport coordination and exceptions.", tag: "Operations" },
  { icon: "▧", title: "Documents", href: "/documents", desc: "Secure company documents, attachments, versions and controlled access.", tag: "Operations" },
  { icon: "◷", title: "Tasks & Reminders", href: "/tasks", desc: "Follow-ups, customer commitments, due dates and team work queues.", tag: "Team productivity" },
  { icon: "▥", title: "Reports", href: "/reports", desc: "Sales activity, pipeline health, margins, direct costs and salesperson performance.", tag: "Management" },
  { icon: "≡", title: "Audit Log", href: "/audit", desc: "Read-only history of company changes, approvals and user actions.", tag: "Governance" },
  { icon: "♧", title: "Notifications", href: "/notifications", desc: "Private approval alerts and purchasing workflow updates.", tag: "Team productivity" },
  { icon: "⚙", title: "Administration", href: "/administration", desc: "Company setup, memberships, roles, access policies and settings.", tag: "Restricted access" }
];

const nav = [
  ["⌂", "Overview", "/"], ["◎", "CRM & Customers", "/crm"], ["▤", "Sales & Proformas", "/sales"],
  ["⇄", "Purchasing", "/purchasing"], ["↗", "Profitability", "/profitability"], ["⌁", "Logistics", "/logistics"],
  ["▧", "Documents", "/documents"], ["◷", "Tasks & Reminders", "/tasks"], ["▥", "Reports", "/reports"], ["≡", "Audit Log", "/audit"], ["♧", "Notifications", "/notifications"]
];

export default async function Home() {
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const [{data:customers},{data:leads},{data:sales},{data:purchaseOrders},{data:tasks},{count:unreadNotifications}] = await Promise.all([
    context.supabase.from("customers").select("id").eq("company_id",companyId).limit(5000),
    context.supabase.from("crm_leads").select("id,stage").eq("company_id",companyId).limit(5000),
    context.supabase.from("sales_documents").select("id,status,grand_total,vat_total").eq("company_id",companyId).limit(5000),
    context.supabase.from("purchase_orders").select("id,status").eq("company_id",companyId).limit(5000),
    context.supabase.from("tasks").select("id,status").eq("company_id",companyId).limit(5000),
    context.supabase.from("notifications").select("id",{count:"exact",head:true}).eq("company_id",companyId).is("read_at",null)
  ]);
  const openLeads = (leads??[]).filter(row=>!["won","lost"].includes(row.stage)).length;
  const openTasks = (tasks??[]).filter(row=>["open","in_progress"].includes(row.status)).length;
  const approvedSales = (sales??[]).filter(row=>["approved","sent","accepted"].includes(row.status));
  const netSales = approvedSales.reduce((sum,row)=>sum+Number(row.grand_total)-Number(row.vat_total),0);
  const money = new Intl.NumberFormat("en-ET",{style:"currency",currency:"ETB",maximumFractionDigits:0}).format(netSales);
  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand"><div className="brand-row"><div className="brand-mark">B</div><div><div className="brand-name">BOKAN ERP</div><div className="brand-sub">COMMERCIAL PLATFORM</div></div></div></div>
        <div><div className="nav-label">Workspace</div><nav className="nav-list">{nav.map(([icon,label,href],i)=><a key={label} className={`nav-item ${i===0?"active":""}`} href={href}><span className="nav-icon">{icon}</span>{label}{href==="/notifications"&&unreadNotifications?<span className="nav-count">{unreadNotifications}</span>:null}</a>)}</nav></div>
        <div><div className="nav-label">Management</div><nav className="nav-list"><a className="nav-item" href="/administration"><span className="nav-icon">⚙</span>Administration</a></nav></div>
        <div className="sidebar-foot">BOKAN ERP V7<br/>New architecture · Preview build<br/>No legacy data imported.</div>
      </aside>
      <section className="main">
        <header className="topbar"><div className="crumb">Workspace <span style={{color:"#c0c9ca"}}>/</span> Overview</div><div className="top-actions"><CompanySwitcher companies={context.companies} activeCompanyId={context.active.companyId} /><div className="avatar">{context.user.email?.slice(0,1).toUpperCase() ?? "B"}</div><SignOutButton /></div></header>
        <div className="content">
          <div className="welcome"><div><div className="eyebrow">Commercial operations · {context.active.displayName}</div><h1>Good morning.</h1><p className="subhead">A clean V7 workspace is taking shape around secure company-aware operations.</p></div><div className="date-chip">BOKAN ERP · VERSION 7</div></div>
          <div className="notice"><div>◈</div><div><strong>V7 review environment — not yet approved for live transactions</strong>The new V7 database is connected and company-isolated. This workspace shows only real records in the active company; no legacy data or sample figures have been imported. Continue using Peachtree for receipts, supplier payments and accounting.</div></div>
          <div className="grid-kpi">
            <div className="kpi"><div className="kpi-label">Customers</div><div className="kpi-value">{customers?.length??0}</div><div className="kpi-foot">Active company directory</div></div>
            <div className="kpi"><div className="kpi-label">Open opportunities</div><div className="kpi-value">{openLeads}</div><div className="kpi-foot">CRM pipeline</div></div>
            <div className="kpi"><div className="kpi-label">Approved sales · net VAT</div><div className="kpi-value" style={{fontSize:18}}>{money}</div><div className="kpi-foot">{approvedSales.length} approved / sent / accepted</div></div>
            <div className="kpi"><div className="kpi-label">Open tasks</div><div className="kpi-value">{openTasks}</div><div className="kpi-foot">{tasks?.length??0} tasks and reminders</div></div>
          </div>
          <div className="section-head"><h2>Application modules</h2><span>Open a workspace to view its implementation scope</span></div>
          <div className="module-grid">{modules.map((m)=><a className="module module-link" href={m.href} key={m.title}><div className="module-icon">{m.icon}</div><h3>{m.title}</h3><p>{m.desc}</p><div className="module-tag">{m.tag} · Open workspace →</div></a>)}</div>
          <div className="bottom-grid">
            <section className="panel"><h2>Implementation sequence</h2><p className="muted">Build security and workflows before onboarding fresh records.</p><div className="status-list"><div className="status-row"><span>Application shell and workspace routes</span><span className="status-pill">Added</span></div><div className="status-row"><span>Authentication and company access</span><span className="status-pill">Active</span></div><div className="status-row"><span>CRM, sales, purchasing and profitability</span><span className="status-pill">Preview build</span></div><div className="status-row"><span>Logistics and management reports</span><span className="status-pill">Preview build</span></div><div className="status-row"><span>Documents, administration and release verification</span><span className="status-pill">In progress</span></div></div></section>
            <section className="panel"><h2>Company access</h2><p className="muted">Your active V7 company is verified against the membership table on the server.</p><div className="status-list">{context.companies.map((company) => <div className="status-row" key={company.companyId}><span>{company.displayName}</span><span className="status-pill">{company.role}</span></div>)}</div></section>
            <section className="panel"><h2>Strict fresh-data policy</h2><p className="muted">V7 starts with zero business records.</p><div className="empty-state">No legacy customers, stock, suppliers, purchases, sales, prices or balances are imported. The existing production database remains untouched.</div></section>
          </div>
          <div className="footer"><span>© BOKAN ERP · Commercial operations platform</span><span>Fresh database · Secure by design</span></div>
        </div>
      </section>
    </main>
  );
}
