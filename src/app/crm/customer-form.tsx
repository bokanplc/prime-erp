"use client";

import { useState } from "react";
import { createCustomer, updateCustomer } from "./actions";

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


export function CustomerEditForm({ customer }: {
  customer: {
    id: string;
    legal_name: string;
    display_name: string;
    phone: string | null;
    email: string | null;
    tax_id: string | null;
    address: string | null;
    notes: string | null;
  };
}) {
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [success, setSuccess] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    setSuccess(false);
    const form = event.currentTarget;
    try {
      const result = await updateCustomer(new FormData(form));
      setMessage(result.message);
      setSuccess(result.ok);
    } catch {
      setMessage("The customer update could not be completed. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="record-form" onSubmit={submit}>
      <input type="hidden" name="customerId" value={customer.id} />
      <div className="form-grid">
        <label>Legal name <span>*</span><input name="legalName" required maxLength={200} defaultValue={customer.legal_name} /></label>
        <label>Display name<input name="displayName" maxLength={120} defaultValue={customer.display_name} /></label>
        <label>Phone<input name="phone" maxLength={50} defaultValue={customer.phone ?? ""} /></label>
        <label>Email<input name="email" type="email" maxLength={254} defaultValue={customer.email ?? ""} /></label>
        <label>Tax ID<input name="taxId" maxLength={80} defaultValue={customer.tax_id ?? ""} /></label>
        <label>Address<input name="address" maxLength={300} defaultValue={customer.address ?? ""} /></label>
        <label className="form-wide">Notes<textarea name="notes" rows={3} maxLength={2000} defaultValue={customer.notes ?? ""} /></label>
      </div>
      {message ? <p className={success ? "form-success" : "form-error"} role="status">{message}</p> : null}
      <div className="form-actions"><button type="submit" disabled={busy}>{busy ? "Saving…" : "Update customer"}</button></div>
    </form>
  );
}
