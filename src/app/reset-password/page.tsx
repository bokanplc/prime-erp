"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export default function ResetPasswordPage() {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (password.length < 8) {
      setError("Use a password with at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError("The passwords do not match.");
      return;
    }
    setBusy(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      setSuccess(true);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Password could not be updated. Request a new recovery link.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-mark">B</div>
        <div className="eyebrow">BOKAN ERP · V7</div>
        <h1>Set a new password</h1>
        {success ? (
          <>
            <p role="status">Your password has been updated. You can now return to sign in.</p>
            <Link className="auth-secondary" href="/login">Return to sign in</Link>
          </>
        ) : (
          <form onSubmit={submit} className="auth-form">
            <label htmlFor="new-password">New password</label>
            <input id="new-password" type="password" autoComplete="new-password" minLength={8} required value={password} onChange={(event) => setPassword(event.target.value)} />
            <label htmlFor="confirm-password">Confirm new password</label>
            <input id="confirm-password" type="password" autoComplete="new-password" minLength={8} required value={confirm} onChange={(event) => setConfirm(event.target.value)} />
            {error ? <p className="auth-error" role="alert">{error}</p> : null}
            <button type="submit" disabled={busy}>{busy ? "Updating…" : "Update password"}</button>
          </form>
        )}
      </section>
    </main>
  );
}
