"use client";

import { useState } from "react";
import { createCustomer } from "./actions";

export function CustomerForm() {
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [success, setSuccess] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    setSuccess(false);
    const form = event.currentTarget;
    const result = await createCustomer(new FormData(form));
    setMessage(result.message);
    setSuccess(result.ok);
    if (result.ok) form.reset();
    setBusy(false);
  }

  return (
    <form className="record-form" onSubmit={submit}>
      <div className="form-grid">
        <label>Legal name <span>*</span><input name="legalName" required maxLength={200} /></label>
        <label>Display name<input name="displayName" maxLength={120} /></label>
        <label>Phone<input name="phone" maxLength={50} /></label>
        <label>Email<input name="email" type="email" maxLength={254} /></label>
        <label>Tax ID<input name="taxId" maxLength={80} /></label>
        <label>Address<input name="address" maxLength={300} /></label>
        <label className="form-wide">Notes<textarea name="notes" rows={3} maxLength={2000} /></label>
      </div>
      {message ? <p className={success ? "form-success" : "form-error"} role="status">{message}</p> : null}
      <div className="form-actions"><button type="submit" disabled={busy}>{busy ? "Saving…" : "Save customer"}</button></div>
    </form>
  );
}
