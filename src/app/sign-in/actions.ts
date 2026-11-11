"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) redirect("/sign-in?error=missing");

  let authenticationFailed = false;
  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    authenticationFailed = Boolean(error);
  } catch {
    redirect("/sign-in?error=configuration");
  }

  if (authenticationFailed) redirect("/sign-in?error=credentials");
  redirect("/");
}
