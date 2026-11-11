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
