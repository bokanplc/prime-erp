import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { initializeFirstOwnerWorkspace } from "./actions";

type Props = { searchParams: Promise<{ error?: string }> };

export const dynamic = "force-dynamic";

export default async function SetupPage({ searchParams }: Props) {
  const params = await searchParams;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (user) {
    const { data: memberships } = await supabase
      .from("company_memberships")
      .select("company_id")
      .eq("user_id", user.id)
      .eq("is_active", true)
      .limit(1);
    if (memberships?.length) redirect("/");
  }

  const errorMessage = params.error === "invite"
    ? "The first administrator account must be invited and email-verified by the Supabase project administrator."
    : params.error === "failed"
      ? "Workspace initialization could not be completed. Confirm that this is the invited administrator account and try again."
      : null;

  return (
    <main className="auth-shell">
      <section className="auth-card">
        <Link className="auth-brand" href="/"><span className="auth-mark">B</span><span>BOKAN ERP</span></Link>
        <div className="eyebrow">BOKAN ERP · V7 first-time setup</div>
        <h1>Initialize your workspace</h1>
        <p className="auth-copy">The V7 database is isolated and empty. This one-time step creates the BlackRock Investment PLC workspace and assigns the verified account as its administrator.</p>
        <div className="auth-alert">No customers, suppliers, products, stock, sales, purchases, prices or historical business records will be created or imported.</div>
        {errorMessage ? <p className="auth-error" role="alert">{errorMessage}</p> : null}
        {user ? (
          <form action={initializeFirstOwnerWorkspace} className="auth-form">
            <p>Signed in as <strong>{user.email}</strong>.</p>
            <button type="submit">Create the BlackRock workspace</button>
          </form>
        ) : (
          <div className="auth-form">
            <p>Sign in with the invited and verified administrator account to continue.</p>
            <Link className="auth-link" href="/sign-in">Go to secure sign in →</Link>
          </div>
        )}
        <p className="auth-foot">This is a one-time administrator bootstrap. Public self-registration is disabled.</p>
      </section>
    </main>
  );
}
