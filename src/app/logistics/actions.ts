"use server";

import { revalidatePath } from "next/cache";
import { getCompanyContext } from "@/lib/auth/company-context";

const deliveryWriters = ["owner", "admin", "manager", "sales", "operations", "data_entry"];
const deliveryStatuses = ["planned", "scheduled", "dispatched", "delivered", "delayed", "cancelled"];

export async function createDeliveryJob(formData: FormData): Promise<void> {
  const salesDocumentId = String(formData.get("salesDocumentId") ?? "").trim();
  const plannedFor = String(formData.get("plannedFor") ?? "").trim();
  const carrierName = String(formData.get("carrierName") ?? "").trim();
  const vehicleReference = String(formData.get("vehicleReference") ?? "").trim();
  const deliveryAddress = String(formData.get("deliveryAddress") ?? "").trim();

  if (!salesDocumentId || (plannedFor && Number.isNaN(Date.parse(plannedFor)))) return;
  const context = await getCompanyContext();
  if (!deliveryWriters.includes(context.active.role)) return;

  const { data: document } = await context.supabase.from("sales_documents")
    .select("id,customer_id,status")
    .eq("id", salesDocumentId)
    .eq("company_id", context.active.companyId)
    .in("status", ["approved", "sent", "accepted"])
    .maybeSingle();
  if (!document) return;

  const reference = `DL-${new Date().toISOString().slice(0,10).replaceAll("-", "")}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
  await context.supabase.from("delivery_jobs").insert({
    company_id: context.active.companyId,
    sales_document_id: document.id,
    customer_id: document.customer_id,
    delivery_reference: reference,
    planned_for: plannedFor || null,
    status: "planned",
    carrier_name: carrierName || null,
    vehicle_reference: vehicleReference || null,
    delivery_address: deliveryAddress || null,
    created_by: context.user.id
  });

  revalidatePath("/logistics");
}

export async function updateDeliveryStatus(formData: FormData): Promise<void> {
  const deliveryId = String(formData.get("deliveryId") ?? "").trim();
  const status = String(formData.get("status") ?? "").trim();
  const exceptionNotes = String(formData.get("exceptionNotes") ?? "").trim();
  if (!deliveryId || !deliveryStatuses.includes(status)) return;

  const context = await getCompanyContext();
  if (!deliveryWriters.includes(context.active.role)) return;

  const now = new Date().toISOString();
  const updates: Record<string, string | null> = { status, exception_notes: exceptionNotes || null };
  if (status === "dispatched") updates.dispatched_at = now;
  if (status === "delivered") updates.delivered_at = now;

  await context.supabase.from("delivery_jobs")
    .update(updates)
    .eq("id", deliveryId)
    .eq("company_id", context.active.companyId);

  revalidatePath("/logistics");
}
