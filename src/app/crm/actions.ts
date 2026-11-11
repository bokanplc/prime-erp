"use server";

import { revalidatePath } from "next/cache";
import { getCompanyContext } from "@/lib/auth/company-context";

export type CustomerActionResult = { ok: boolean; message: string };

const crmWriters = ["owner", "admin", "manager", "sales", "data_entry"];
const leadStages = ["new", "qualified", "proposal", "negotiation", "won", "lost"];

export async function createCustomer(formData: FormData): Promise<CustomerActionResult> {
  const legalName = String(formData.get("legalName") ?? "").trim();
  const displayName = String(formData.get("displayName") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const taxId = String(formData.get("taxId") ?? "").trim();
  const address = String(formData.get("address") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (legalName.length < 2 || legalName.length > 200) {
    return { ok: false, message: "Enter a customer legal name between 2 and 200 characters." };
  }
  if (displayName.length > 120 || phone.length > 50 || email.length > 254 || taxId.length > 80 || address.length > 300 || notes.length > 2000) {
    return { ok: false, message: "One or more customer fields exceed the allowed length." };
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid email address." };
  }

  const context = await getCompanyContext();
  if (!crmWriters.includes(context.active.role)) {
    return { ok: false, message: "Your role does not allow customer creation." };
  }

  const { error } = await context.supabase.from("customers").insert({
    company_id: context.active.companyId,
    legal_name: legalName,
    display_name: displayName || legalName,
    phone: phone || null,
    email: email || null,
    tax_id: taxId || null,
    address: address || null,
    notes: notes || null,
    created_by: context.user.id
  });

  if (error) return { ok: false, message: error.code === "23505" ? "That customer code or record already exists." : "Customer could not be saved. Check your access and try again." };
  revalidatePath("/crm");
  return { ok: true, message: "Customer saved." };
}

export async function updateCustomer(formData: FormData): Promise<CustomerActionResult> {
  const customerId = String(formData.get("customerId") ?? "").trim();
  const legalName = String(formData.get("legalName") ?? "").trim();
  const displayName = String(formData.get("displayName") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const taxId = String(formData.get("taxId") ?? "").trim();
  const address = String(formData.get("address") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (!customerId || legalName.length < 2 || legalName.length > 200) {
    return { ok: false, message: "Enter a customer legal name between 2 and 200 characters." };
  }
  if (displayName.length > 120 || phone.length > 50 || email.length > 254 || taxId.length > 80 || address.length > 300 || notes.length > 2000) {
    return { ok: false, message: "One or more customer fields exceed the allowed length." };
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid email address." };
  }

  const context = await getCompanyContext();
  if (!crmWriters.includes(context.active.role)) {
    return { ok: false, message: "Your role does not allow customer updates." };
  }

  const { error } = await context.supabase.from("customers")
    .update({
      legal_name: legalName,
      display_name: displayName || legalName,
      phone: phone || null,
      email: email || null,
      tax_id: taxId || null,
      address: address || null,
      notes: notes || null
    })
    .eq("id", customerId)
    .eq("company_id", context.active.companyId);

  if (error) return { ok: false, message: "Customer details could not be updated. Check your access and try again." };
  revalidatePath("/crm");
  revalidatePath(`/crm/customers/${customerId}`);
  return { ok: true, message: "Customer details updated." };
}

export async function createLead(formData: FormData): Promise<CustomerActionResult> {
  const title = String(formData.get("title") ?? "").trim();
  const contactName = String(formData.get("contactName") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const source = String(formData.get("source") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();
  const customerId = String(formData.get("customerId") ?? "").trim();
  const nextFollowUpDate = String(formData.get("nextFollowUpDate") ?? "").trim();
  const estimatedValueInput = String(formData.get("estimatedValue") ?? "").trim();
  const estimatedValue = estimatedValueInput ? Number(estimatedValueInput) : null;

  if (title.length < 2 || title.length > 180) {
    return { ok: false, message: "Enter a lead or opportunity name between 2 and 180 characters." };
  }
  if (contactName.length > 120 || phone.length > 40 || email.length > 254 || source.length > 80 || notes.length > 2000) {
    return { ok: false, message: "One or more lead fields exceed the allowed length." };
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid email address." };
  }
  if (estimatedValue !== null && (!Number.isFinite(estimatedValue) || estimatedValue < 0)) {
    return { ok: false, message: "Estimated value must be a non-negative amount in ETB." };
  }
  if (nextFollowUpDate && !/^\d{4}-\d{2}-\d{2}$/.test(nextFollowUpDate)) {
    return { ok: false, message: "Enter a valid next follow-up date." };
  }

  const context = await getCompanyContext();
  if (!crmWriters.includes(context.active.role)) {
    return { ok: false, message: "Your role does not allow lead creation." };
  }

  const nextFollowUpAt = nextFollowUpDate
    ? new Date(`${nextFollowUpDate}T06:00:00.000Z`).toISOString()
    : null;

  const { error } = await context.supabase.from("crm_leads").insert({
    company_id: context.active.companyId,
    customer_id: customerId || null,
    title,
    contact_name: contactName || null,
    phone: phone || null,
    email: email || null,
    source: source || null,
    notes: notes || null,
    estimated_value: estimatedValue,
    next_follow_up_at: nextFollowUpAt,
    assigned_to: context.user.id,
    created_by: context.user.id
  });

  if (error) return { ok: false, message: "Lead could not be saved. Check your company access and try again." };
  revalidatePath("/crm");
  return { ok: true, message: "Lead saved." };
}

export async function updateLeadStage(formData: FormData): Promise<void> {
  const leadId = String(formData.get("leadId") ?? "").trim();
  const stage = String(formData.get("stage") ?? "").trim();
  if (!leadId || !leadStages.includes(stage)) return;

  const context = await getCompanyContext();
  if (!crmWriters.includes(context.active.role)) return;

  await context.supabase.from("crm_leads")
    .update({ stage })
    .eq("id", leadId)
    .eq("company_id", context.active.companyId);
  revalidatePath("/crm");
}

export async function recordCrmActivity(formData: FormData): Promise<CustomerActionResult> {
  const activityType = String(formData.get("activityType") ?? "");
  const subject = String(formData.get("subject") ?? "").trim();
  const details = String(formData.get("details") ?? "").trim();
  const customerId = String(formData.get("customerId") ?? "").trim();
  const leadId = String(formData.get("leadId") ?? "").trim();
  const dueDate = String(formData.get("dueDate") ?? "").trim();

  if (!["call", "visit", "meeting", "email", "note", "reminder"].includes(activityType)) {
    return { ok: false, message: "Select a valid activity type." };
  }
  if (subject.length < 2 || subject.length > 180 || (!customerId && !leadId)) {
    return { ok: false, message: "Choose a customer or lead and enter an activity subject." };
  }
  if (activityType === "reminder" && !/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) {
    return { ok: false, message: "Choose a due date for this reminder." };
  }

  const context = await getCompanyContext();
  if (!crmWriters.includes(context.active.role)) {
    return { ok: false, message: "Your role does not allow CRM activity entry." };
  }

  if (activityType === "reminder") {
    const { error } = await context.supabase.from("tasks").insert({
      company_id: context.active.companyId,
      title: subject,
      details: details || null,
      due_at: new Date(`${dueDate}T06:00:00.000Z`).toISOString(),
      status: "open",
      customer_id: customerId || null,
      lead_id: leadId || null,
      assigned_to: context.user.id,
      created_by: context.user.id
    });
    if (error) return { ok: false, message: "Reminder could not be saved. Check the selected record and your access." };
    revalidatePath("/crm");
    revalidatePath("/tasks");
    return { ok: true, message: "Reminder created in Tasks & Reminders." };
  }

  const { error } = await context.supabase.from("crm_activities").insert({
    company_id: context.active.companyId,
    activity_type: activityType,
    subject,
    details: details || null,
    customer_id: customerId || null,
    lead_id: leadId || null,
    assigned_to: context.user.id,
    created_by: context.user.id
  });

  if (error) return { ok: false, message: "Activity could not be saved. Check the selected record and your access." };
  revalidatePath("/crm");
  return { ok: true, message: "CRM activity saved." };
}
