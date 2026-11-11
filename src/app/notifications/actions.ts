"use server";

import { revalidatePath } from "next/cache";
import { getCompanyContext } from "@/lib/auth/company-context";

export async function markNotificationRead(formData: FormData): Promise<void> {
  const notificationId=String(formData.get("notificationId")??"").trim();
  if(!notificationId)return;
  const context=await getCompanyContext();
  await context.supabase.from("notifications")
    .update({read_at:new Date().toISOString()})
    .eq("id",notificationId)
    .eq("company_id",context.active.companyId)
    .is("read_at",null);
  revalidatePath("/notifications");
  revalidatePath("/");
}

export async function markAllNotificationsRead(): Promise<void> {
  const context=await getCompanyContext();
  await context.supabase.from("notifications")
    .update({read_at:new Date().toISOString()})
    .eq("company_id",context.active.companyId)
    .is("read_at",null);
  revalidatePath("/notifications");
  revalidatePath("/");
}
