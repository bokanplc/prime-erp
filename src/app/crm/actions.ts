"use server";

import { revalidatePath } from "next/cache";
import { getCompanyContext } from "@/lib/auth/company-context";

export type CustomerActionResult = { ok: boolean; message: string };

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
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid email address." };
  }

  const context = await getCompanyContext();
  if (!["owner", "admin", "manager", "sales", "data_entry"].includes(context.active.role)) {
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

export async function createLead(formData: FormData): Promise<CustomerActionResult> {
  const title = String(formData.get("title") ?? "").trim();
  const contactName = String(formData.get("contactName") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const source = String(formData.get("source") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();

  if (title.length < 2 || title.length > 180) {
    return { ok: false, message: "Enter a lead or opportunity name between 2 and 180 characters." };
  }
  if (email && !/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid email address." };
  }

  const context = await getCompanyContext();
  if (!["owner", "admin", "manager", "sales", "data_entry"].includes(context.active.role)) {
    return { ok: false, message: "Your role does not allow lead creation." };
  }

  const { error } = await context.supabase.from("crm_leads").insert({
    company_id: context.active.companyId,
    title,
    contact_name: contactName || null,
    phone: phone || null,
    email: email || null,
    source: source || null,
    notes: notes || null,
    assigned_to: context.user.id,
    created_by: context.user.id
  });

  if (error) return { ok: false, message: "Lead could not be saved. Check your company access and try again." };
  revalidatePath("/crm");
  return { ok: true, message: "Lead saved." };
}

export async function recordCrmActivity(formData: FormData): Promise<CustomerActionResult> {
  const activityType = String(formData.get("activityType") ?? "");
  const subject = String(formData.get("subject") ?? "").trim();
  const details = String(formData.get("details") ?? "").trim();
  const customerId = String(formData.get("customerId") ?? "").trim();
  const leadId = String(formData.get("leadId") ?? "").trim();

  if (!["call", "visit", "meeting", "email", "note", "reminder"].includes(activityType)) {
    return { ok: false, message: "Select a valid activity type." };
  }
  if (subject.length < 2 || subject.length > 180 || (!customerId && !leadId)) {
    return { ok: false, message: "Choose a customer or lead and enter an activity subject." };
  }

  const context = await getCompanyContext();
  if (!["owner", "admin", "manager", "sales", "data_entry"].includes(context.active.role)) {
    return { ok: false, message: "Your role does not allow CRM activity entry." };
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
