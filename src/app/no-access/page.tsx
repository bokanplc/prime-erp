import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { bootstrapInitialCompanies } from "./actions";

type Props = { searchParams: Promise<{ error?: string }> };

export const dynamic = "force-dynamic";

export const dynamic = "force-dynamic";

export default async function NoAccessPage({ searchParams }: Props) {
  const supabase = await createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) redirect("/login");
  const params = await searchParams;

  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-mark">B</div>
        <div className="eyebrow">BOKAN ERP · V7</div>
        <h1>Company access pending</h1>
        <p>Your V7 sign-in is valid, but this account is not yet a member of either company.</p>
        {params.error === "bootstrap" ? (
          <div className="auth-alert" role="alert">
            Initial setup was not completed. Only the first verified account invited by the V7 Supabase project administrator can initialize the two companies. If setup has already been completed, ask the company owner to grant your membership.
          </div>
        ) : (
          <div className="auth-alert">
            If you are the first administrator invited to V7, use the one-time setup below. Other employees must wait for the company owner to grant their company membership.
          </div>
        )}
        <form action={bootstrapInitialCompanies}>
          <button type="submit">Initialize both companies as first owner</button>
        </form>
        <p className="auth-footnote">This one-time action creates Prime Investment Group and BlackRock Investment PLC and assigns the invited first administrator as owner of both. It imports no legacy data.</p>
        <Link className="auth-link" href="/login">Return to sign in</Link>
        <p className="auth-footnote">Signed in as {user.email ?? "your V7 account"}.</p>
      </section>
    </main>
  );
}
