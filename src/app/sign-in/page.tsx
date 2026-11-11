import Link from "next/link";
import { signIn } from "./actions";
import { getSupabasePublicEnv } from "@/lib/supabase/env";

type SignInPageProps = {
  searchParams: Promise<{ error?: string }>;
};

const messages: Record<string, string> = {
  missing: "Enter both your email address and password.",
  credentials: "The sign-in details could not be verified.",
  configuration: "Secure sign-in is not configured for this environment yet."
};

export default async function SignInPage({ searchParams }: SignInPageProps) {
  const { error } = await searchParams;
  const configured = Boolean(getSupabasePublicEnv());

  return (
    <main className="auth-shell">
      <section className="auth-card">
        <Link className="auth-brand" href="/"><span className="auth-mark">B</span><span>BOKAN ERP</span></Link>
        <div className="eyebrow">Secure workspace access</div>
        <h1>Sign in</h1>
        <p className="auth-copy">Use an account invited by your company administrator. Public self-registration is disabled.</p>
        {!configured ? (
          <div className="auth-alert" role="status">Authentication is not configured for this preview. No sign-in attempt or business-data connection is available.</div>
        ) : (
          <form action={signIn} className="auth-form">
            <label htmlFor="email">Email address</label>
            <input id="email" name="email" type="email" autoComplete="username" required />
            <label htmlFor="password">Password</label>
            <input id="password" name="password" type="password" autoComplete="current-password" required />
            <button type="submit">Sign in securely</button>
          </form>
        )}
        {error && <p className="auth-error" role="alert">{messages[error] ?? "Sign-in failed."}</p>}
        <p className="auth-foot">No account? Contact your authorized BOKAN ERP administrator.</p>
      </section>
    </main>
  );
}
