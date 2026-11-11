import Link from "next/link";

export default function SetupPage() {
  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-mark">B</div>
        <div className="eyebrow">BOKAN ERP · V7</div>
        <h1>Secure setup required</h1>
        <p>This deployment is not connected to an isolated V7 authentication and database environment yet.</p>
        <div className="auth-alert">Access to business workspaces is blocked until the V7 Supabase URL and public client key are configured and the V7 schema, row-level security and company-access policies have been reviewed.</div>
        <p className="auth-footnote">No legacy database is connected. No business records have been loaded. Do not enter live business information in this environment.</p>
        <Link className="auth-link" href="https://supabase.com/docs/guides/auth/server-side/nextjs">Supabase secure Next.js setup guide ↗</Link>
      </section>
    </main>
  );
}
