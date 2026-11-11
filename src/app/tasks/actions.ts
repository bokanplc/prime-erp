"use server";

import { revalidatePath } from "next/cache";
import { getCompanyContext } from "@/lib/auth/company-context";

const taskWriters = ["owner", "admin", "manager", "sales", "purchasing", "operations", "data_entry"];
const taskStatuses = ["open", "in_progress", "completed", "cancelled"];

export async function createTask(formData: FormData): Promise<void> {
  const title = String(formData.get("title") ?? "").trim();
  const details = String(formData.get("details") ?? "").trim();
  const dueDate = String(formData.get("dueDate") ?? "").trim();
  const customerId = String(formData.get("customerId") ?? "").trim();
  const leadId = String(formData.get("leadId") ?? "").trim();

  if (title.length < 2 || title.length > 180) return;
  if (dueDate && !/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) return;
  const dueAt = dueDate ? new Date(`${dueDate}T06:00:00.000Z`) : null;
  if (dueAt && Number.isNaN(dueAt.getTime())) return;

  const context = await getCompanyContext();
  if (!taskWriters.includes(context.active.role)) return;

  await context.supabase.from("tasks").insert({
    company_id: context.active.companyId,
    title,
    details: details || null,
    due_at: dueAt?.toISOString() ?? null,
    status: "open",
    customer_id: customerId || null,
    lead_id: leadId || null,
    assigned_to: context.user.id,
    created_by: context.user.id
  });

  revalidatePath("/tasks");
  revalidatePath("/crm");
}

export async function updateTaskStatus(formData: FormData): Promise<void> {
  const taskId = String(formData.get("taskId") ?? "").trim();
  const status = String(formData.get("status") ?? "").trim();
  if (!taskId || !taskStatuses.includes(status)) return;

  const context = await getCompanyContext();
  if (!taskWriters.includes(context.active.role)) return;

  await context.supabase.from("tasks")
    .update({
      status,
      completed_at: status === "completed" ? new Date().toISOString() : null
    })
    .eq("id", taskId)
    .eq("company_id", context.active.companyId);

  revalidatePath("/tasks");
  revalidatePath("/crm");
}
