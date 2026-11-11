import { redirect } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";

type WorkspacePageProps = {
  eyebrow: string;
  title: string;
  description: string;
  capabilities: string[];
};

export async function WorkspacePage({ eyebrow, title, description, capabilities }: WorkspacePageProps) {
  let context;
  try {
    context = await getCompanyContext();
  } catch {
    redirect("/login");
  }

  return (
    <main className="workspace-page">
      <a className="back-link" href="/">← BOKAN ERP overview</a>
      <div className="eyebrow">{eyebrow} · {context.active.displayName}</div>
      <h1>{title}</h1>
      <p className="workspace-description">{description}</p>
      <section className="workspace-notice" role="status">
        <strong>Workspace foundation — secure company access verified</strong>
        This area is being implemented. No business records have been imported or created. The workspace is scoped to the active V7 company; fresh, reconciled data will be onboarded later through a separately approved process.
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
