"use client";

import { FormEvent, Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

function LoginForm() {
  const search = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");
    setNotice("");
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
      if (signInError) throw signInError;
      const next = search.get("next");
      window.location.assign(next && next.startsWith("/") && !next.startsWith("//") ? next : "/");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Unable to sign in. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  async function googleSignIn() {
    setBusy(true);
    setError("");
    try {
      const supabase = createSupabaseBrowserClient();
      const next = search.get("next");
      const safeNext = next && next.startsWith("/") && !next.startsWith("//") ? next : "/";
      const { error: oauthError } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(safeNext)}` }
      });
      if (oauthError) throw oauthError;
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Google sign-in could not be started.");
      setBusy(false);
    }
  }

  async function sendRecovery() {
    setError("");
    setNotice("");
    if (!email.trim()) {
      setError("Enter your work email first, then choose Forgot password.");
      return;
    }
    setBusy(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: recoveryError } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`
      });
      if (recoveryError) throw recoveryError;
      setNotice("If an account exists for that email, a password-reset link has been sent.");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not send the recovery email. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <form onSubmit={submit} className="auth-form">
        <label htmlFor="email">Email address</label>
        <input id="email" type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} />
        <label htmlFor="password">Password</label>
        <input id="password" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
        <button type="submit" disabled={busy}>{busy ? "Please wait…" : "Sign in securely"}</button>
      </form>
      <button type="button" className="auth-secondary" onClick={googleSignIn} disabled={busy}>Continue with Google</button>
      <button type="button" className="auth-link" onClick={sendRecovery} disabled={busy}>Forgot password?</button>
      {notice ? <p className="auth-foot" role="status">{notice}</p> : null}
      {error ? <p className="auth-error" role="alert">{error}</p> : null}
    </>
  );
}

export default function LoginPage() {
  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-mark">B</div>
        <div className="eyebrow">BOKAN ERP · V7</div>
        <h1>Sign in</h1>
        <p>Use an account explicitly provisioned for the new V7 environment.</p>
        <Suspense fallback={<div className="auth-alert">Preparing secure sign-in…</div>}>
          <LoginForm />
        </Suspense>
        <p className="auth-footnote">V7 credentials are separate. Legacy application accounts are not copied automatically.</p>
      </section>
    </main>
  );
}
