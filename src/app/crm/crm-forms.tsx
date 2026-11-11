"use client";

import { useState } from "react";
import { createLead, recordCrmActivity } from "./actions";

function ActionForm({ action, children, buttonLabel }: {
  action: (formData: FormData) => Promise<{ ok: boolean; message: string }>;
  children: React.ReactNode;
  buttonLabel: string;
}) {
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [success, setSuccess] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    const form = event.currentTarget;
    try {
      const result = await action(new FormData(form));
      setMessage(result.message);
      setSuccess(result.ok);
      if (result.ok) form.reset();
    } catch {
      setMessage("The request could not be completed. Please check your access and try again.");
      setSuccess(false);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="record-form" onSubmit={submit}>
      {children}
      {message ? <p className={success ? "form-success" : "form-error"} role="status">{message}</p> : null}
      <div className="form-actions"><button type="submit" disabled={busy}>{busy ? "Saving…" : buttonLabel}</button></div>
    </form>
  );
}

export function LeadForm() {
  return (
    <ActionForm action={createLead} buttonLabel="Save lead">
      <div className="form-grid">
        <label>Opportunity / lead name <span>*</span><input name="title" required maxLength={180} /></label>
        <label>Contact person<input name="contactName" maxLength={120} /></label>
        <label>Phone<input name="phone" maxLength={40} /></label>
        <label>Email<input name="email" type="email" maxLength={254} /></label>
        <label>Lead source<input name="source" placeholder="Referral, walk-in, cold call…" maxLength={80} /></label>
        <label className="form-wide">Notes<textarea name="notes" rows={2} maxLength={2000} /></label>
      </div>
    </ActionForm>
  );
}

export function ActivityForm({ customers, leads }: {
  customers: Array<{ id: string; display_name: string; legal_name: string }>;
  leads: Array<{ id: string; title: string }>;
}) {
  return (
    <ActionForm action={recordCrmActivity} buttonLabel="Save activity">
      <div className="form-grid">
        <label>Activity type <span>*</span><select name="activityType" defaultValue="call"><option value="call">Call</option><option value="visit">Visit</option><option value="meeting">Meeting</option><option value="email">Email</option><option value="reminder">Reminder</option><option value="note">Note</option></select></label>
        <label>Customer<select name="customerId" defaultValue=""><option value="">Select customer (optional)</option>{customers.map((customer) => <option key={customer.id} value={customer.id}>{customer.display_name || customer.legal_name}</option>)}</select></label>
        <label>Lead<select name="leadId" defaultValue=""><option value="">Select lead (optional)</option>{leads.map((lead) => <option key={lead.id} value={lead.id}>{lead.title}</option>)}</select></label>
        <label>Subject <span>*</span><input name="subject" required maxLength={180} /></label>
        <label className="form-wide">Details<textarea name="details" rows={2} maxLength={3000} /></label>
      </div>
    </ActionForm>
  );
}
