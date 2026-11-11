import Link from "next/link";

export default function NoAccessPage() {
  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-mark">B</div>
        <div className="eyebrow">BOKAN ERP · V7</div>
        <h1>Company access pending</h1>
        <p>Your sign-in was successful, but this account does not yet have an active membership in a V7 company.</p>
        <div className="auth-alert">Ask the V7 administrator to provision your company membership and role. Legacy memberships are not copied into V7.</div>
        <Link className="auth-link" href="/login">Return to sign in</Link>
      </section>
    </main>
  );
}
