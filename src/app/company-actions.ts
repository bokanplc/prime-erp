"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { getCompanyContext } from "@/lib/auth/company-context";

export async function setActiveCompany(formData: FormData) {
  const requestedId = String(formData.get("companyId") ?? "");
  if (!requestedId) return;

  const context = await getCompanyContext();
  const allowed = context.companies.some((company) => company.companyId === requestedId);
  if (!allowed) throw new Error("You do not have access to that company.");

  const cookieStore = await cookies();
  cookieStore.set("bokan-active-company", requestedId, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30
  });
  revalidatePath("/");
}
