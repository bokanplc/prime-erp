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
  { icon: "⚙", title: "Administration", href: "/administration", desc: "Company setup, memberships, roles, access policies and settings.", tag: "Restricted access" }
];

const nav = [
  ["⌂", "Overview", "/"], ["◎", "CRM & Customers", "/crm"], ["▤", "Sales & Proformas", "/sales"],
  ["⇄", "Purchasing", "/purchasing"], ["↗", "Profitability", "/profitability"], ["⌁", "Logistics", "/logistics"],
  ["▧", "Documents", "/documents"], ["◷", "Tasks & Reminders", "/tasks"], ["▥", "Reports", "/reports"]
];

export default async function Home() {
  const context = await getCompanyContext();
  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand"><div className="brand-row"><div className="brand-mark">B</div><div><div className="brand-name">BOKAN ERP</div><div className="brand-sub">COMMERCIAL PLATFORM</div></div></div></div>
        <div><div className="nav-label">Workspace</div><nav className="nav-list">{nav.map(([icon,label,href],i)=><a key={label} className={`nav-item ${i===0?"active":""}`} href={href}><span className="nav-icon">{icon}</span>{label}</a>)}</nav></div>
        <div><div className="nav-label">Management</div><nav className="nav-list"><a className="nav-item" href="/administration"><span className="nav-icon">⚙</span>Administration</a></nav></div>
        <div className="sidebar-foot">BOKAN ERP V7<br/>New architecture · Preview build<br/>No business data connected.</div>
      </aside>
      <section className="main">
        <header className="topbar"><div className="crumb">Workspace <span style={{color:"#c0c9ca"}}>/</span> Overview</div><div className="top-actions"><CompanySwitcher companies={context.companies} activeCompanyId={context.active.companyId} /><div className="avatar">{context.user.email?.slice(0,1).toUpperCase() ?? "B"}</div><SignOutButton /></div></header>
        <div className="content">
          <div className="welcome"><div><div className="eyebrow">Commercial operations · {context.active.displayName}</div><h1>Good morning.</h1><p className="subhead">A clean V7 workspace is taking shape around secure company-aware operations.</p></div><div className="date-chip">BOKAN ERP · VERSION 7</div></div>
          <div className="notice"><div>◈</div><div><strong>Development environment — not for live transactions</strong>This is the new application foundation. No sample figures or imported business records are displayed. Your active company is isolated by database policies; the new V7 database remains separate from legacy systems.</div></div>
          <div className="grid-kpi">
            <div className="kpi"><div className="kpi-label">Application status</div><div className="kpi-value">Building</div><div className="kpi-foot">V7 foundation</div></div>
            <div className="kpi"><div className="kpi-label">Planned workspaces</div><div className="kpi-value">9</div><div className="kpi-foot">Functional areas defined</div></div>
            <div className="kpi"><div className="kpi-label">Business data</div><div className="kpi-value">Empty</div><div className="kpi-foot">Fresh data onboarding later</div></div>
          </div>
          <div className="section-head"><h2>Application modules</h2><span>Open a workspace to view its implementation scope</span></div>
          <div className="module-grid">{modules.map((m)=><a className="module module-link" href={m.href} key={m.title}><div className="module-icon">{m.icon}</div><h3>{m.title}</h3><p>{m.desc}</p><div className="module-tag">{m.tag} · Open workspace →</div></a>)}</div>
          <div className="bottom-grid">
            <section className="panel"><h2>Implementation sequence</h2><p className="muted">Build security and workflows before onboarding fresh records.</p><div className="status-list"><div className="status-row"><span>Application shell and workspace routes</span><span className="status-pill">Added</span></div><div className="status-row"><span>Authentication and company access</span><span className="status-pill">Pending</span></div><div className="status-row"><span>CRM and commercial workflows</span><span className="status-pill">Pending</span></div><div className="status-row"><span>Reports, audit and release verification</span><span className="status-pill">Pending</span></div></div></section>
            <section className="panel"><h2>Company access</h2><p className="muted">Your active V7 company is verified against the membership table on the server.</p><div className="status-list">{context.companies.map((company) => <div className="status-row" key={company.companyId}><span>{company.displayName}</span><span className="status-pill">{company.role}</span></div>)}</div></section>
            <section className="panel"><h2>Strict fresh-data policy</h2><p className="muted">V7 starts with zero business records.</p><div className="empty-state">No legacy customers, stock, suppliers, purchases, sales, prices or balances are imported. The existing production database remains untouched.</div></section>
          </div>
          <div className="footer"><span>© BOKAN ERP · Commercial operations platform</span><span>Fresh database · Secure by design</span></div>
        </div>
      </section>
    </main>
  );
}
