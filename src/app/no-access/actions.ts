"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function bootstrapInitialCompanies(): Promise<void> {
  const supabase = await createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) redirect("/login");

  const { data: primeCompanyId, error } = await supabase.rpc("bootstrap_initial_companies");
  if (error || typeof primeCompanyId !== "string") {
    redirect("/no-access?error=bootstrap");
  }

  const cookieStore = await cookies();
  cookieStore.set("bokan-active-company", primeCompanyId, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30
  });

  revalidatePath("/");
  revalidatePath("/administration");
  redirect("/");
}
