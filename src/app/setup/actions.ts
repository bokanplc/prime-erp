"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function initializeFirstOwnerWorkspace() {
  const supabase = await createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();

  if (userError || !user) redirect("/sign-in");

  const { error } = await supabase.rpc("bootstrap_initial_companies");
  if (error) {
    const message = error.message.toLowerCase();
    if (message.includes("already been completed")) redirect("/");
    if (message.includes("verified account invited")) redirect("/setup?error=invite");
    redirect("/setup?error=failed");
  }

  redirect("/");
}
