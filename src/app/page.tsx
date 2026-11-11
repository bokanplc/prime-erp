const modules = [
  { icon: "◎", title: "CRM & Customers", desc: "Customer records, leads, pipeline, calls, visits, reminders and complete relationship history.", tag: "Core workspace" },
  { icon: "▤", title: "Sales & Proformas", desc: "Prepare commercial offers, manage sales documents, pricing, VAT and approval stages.", tag: "Core workspace" },
  { icon: "⇄", title: "Purchasing", desc: "Supplier directory, purchase requests, purchase orders and purchase price records.", tag: "Core workspace" },
  { icon: "↗", title: "Profitability", desc: "Landed gross profit and profit after transportation, loading and other direct sales costs.", tag: "Commercial insight" },
  { icon: "⌁", title: "Logistics & Delivery", desc: "Coordinate delivery orders, dispatch milestones, transport costs and exceptions.", tag: "Operations" },
  { icon: "▧", title: "Documents", desc: "Secure company documents, attachments, versions and controlled access.", tag: "Operations" },
  { icon: "◷", title: "Tasks & Reminders", desc: "Follow-ups, customer commitments, due dates and team work queues.", tag: "Team productivity" },
  { icon: "▥", title: "Reports", desc: "Sales activity, pipeline health, margins, direct costs and salesperson performance.", tag: "Management" },
  { icon: "⚙", title: "Administration", desc: "Company memberships, user roles, access policies and organization settings.", tag: "Restricted access" }
];

const nav = [
  ["⌂", "Overview"], ["◎", "CRM & Customers"], ["▤", "Sales & Proformas"], ["⇄", "Purchasing"],
  ["↗", "Profitability"], ["⌁", "Logistics"], ["▧", "Documents"], ["◷", "Tasks & Reminders"], ["▥", "Reports"]
];

export default function Home() {
  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-row"><div className="brand-mark">B</div><div><div className="brand-name">BOKAN ERP</div><div className="brand-sub">COMMERCIAL PLATFORM</div></div></div>
        </div>
        <div>
          <div className="nav-label">Workspace</div>
          <nav className="nav-list">{nav.map(([icon,label],i)=><a key={label} className={`nav-item ${i===0?"active":""}`} href="#"><span className="nav-icon">{icon}</span>{label}</a>)}</nav>
        </div>
        <div>
          <div className="nav-label">Management</div>
          <nav className="nav-list"><a className="nav-item" href="#"><span className="nav-icon">⚙</span>Administration</a></nav>
        </div>
        <div className="sidebar-foot">BOKAN ERP V7<br/>New architecture · Preview build<br/>Business data is not connected.</div>
      </aside>
      <section className="main">
        <header className="topbar">
          <div className="crumb">Workspace <span style={{color:"#c0c9ca"}}>/</span> Overview</div>
          <div className="top-actions"><div className="company-select">Company selection · Setup pending</div><div className="avatar">B</div></div>
        </header>
        <div className="content">
          <div className="welcome">
            <div><div className="eyebrow">Commercial operations</div><h1>Good morning.</h1><p className="subhead">Your business workspace is being built. Core modules are being organized around one secure company-aware platform.</p></div>
            <div className="date-chip">BOKAN ERP · VERSION 7</div>
          </div>
          <div className="notice"><div>◈</div><div><strong>Development environment — not for live transactions</strong>This is the new application foundation. No sample figures are presented as real business data. Sign-in, company access, database persistence and operational workflows will be enabled only after their security checks pass.</div></div>
          <div className="grid-kpi">
            <div className="kpi"><div className="kpi-label">Application status</div><div className="kpi-value">Building</div><div className="kpi-foot">V7 foundation</div></div>
            <div className="kpi"><div className="kpi-label">Business entities</div><div className="kpi-value">2</div><div className="kpi-foot">Prime · BlackRock</div></div>
            <div className="kpi"><div className="kpi-label">Operational modules</div><div className="kpi-value">9</div><div className="kpi-foot">Planned core areas</div></div>
            <div className="kpi"><div className="kpi-label">Live business records</div><div className="kpi-value">—</div><div className="kpi-foot">Fresh data to be supplied later</div></div>
          </div>
          <div className="section-head"><h2>Application modules</h2><span>Designed as independent, connected workspaces</span></div>
          <div className="module-grid">{modules.map((m)=><article className="module" key={m.title}><div className="module-icon">{m.icon}</div><h3>{m.title}</h3><p>{m.desc}</p><div className="module-tag">{m.tag}</div></article>)}</div>
          <div className="bottom-grid">
            <section className="panel"><h2>Implementation sequence</h2><p className="muted">The foundation is being established before business records are loaded.</p><div className="status-list"><div className="status-row"><span>Application shell and design system</span><span className="status-pill">In progress</span></div><div className="status-row"><span>Authentication and company access</span><span className="status-pill">Next</span></div><div className="status-row"><span>CRM and commercial workflows</span><span className="status-pill">Planned</span></div><div className="status-row"><span>Reports, audit and release verification</span><span className="status-pill">Planned</span></div></div></section>
            <section className="panel"><h2>Business data policy</h2><p className="muted">The rebuild starts clean. Existing production data is not being altered.</p><div className="empty-state">No imported customers, stock balances, purchases or sales are shown here.<br/>Fresh reconciled data will be loaded after the application workflows are verified.</div></section>
          </div>
          <div className="footer"><span>© BOKAN ERP · Prime Investment Group / BlackRock Investment PLC</span><span>Secure by design · Built for business operations</span></div>
        </div>
      </section>
    </main>
  );
}