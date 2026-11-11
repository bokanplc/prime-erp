type WorkspacePageProps = {
  eyebrow: string;
  title: string;
  description: string;
  capabilities: string[];
};

export function WorkspacePage({ eyebrow, title, description, capabilities }: WorkspacePageProps) {
  return (
    <main className="workspace-page">
      <a className="back-link" href="/">← BOKAN ERP overview</a>
      <div className="eyebrow">{eyebrow}</div>
      <h1>{title}</h1>
      <p className="workspace-description">{description}</p>
      <section className="workspace-notice" role="status">
        <strong>Workspace foundation — setup not yet connected</strong>
        This area is being implemented. No business records have been imported or created. Records and actions will become available only after secure sign-in, company access and the isolated V7 database pass verification.
      </section>
      <section className="workspace-panel">
        <h2>Planned capabilities</h2>
        <ul>{capabilities.map((item) => <li key={item}>{item}</li>)}</ul>
      </section>
      <section className="workspace-empty">
        <div className="empty-mark">＋</div>
        <h2>No records</h2>
        <p>This workspace is intentionally empty. Fresh, reconciled business data will be supplied and onboarded later through a separately approved process.</p>
      </section>
    </main>
  );
}
